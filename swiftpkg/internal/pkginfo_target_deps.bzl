"""Module for generating data from target dependencies created by `pkginfos`."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels", "lists")
load(":bzl_selects.bzl", "bzl_selects")
load(":deps_indexes.bzl", "deps_indexes")
load(":pkginfo_dependencies.bzl", "pkginfo_dependencies")

# This value is used to group Bazel select conditions
_target_dep_kind = "_target_dep"

def make_pkginfo_target_deps(bazel_labels):
    def _bzl_select_list(pkg_ctx, target_dep, depender_module_name):
        """Return the Bazel labels associated with a target dependency.

        A module will resolve to a single label. A product can resolve to one
        or more labels.

        Args:
            pkg_ctx: A `struct` as returned by `pkg_ctxs.new`.
            target_dep: A `struct` as returned by
                `pkginfos.new_target_dependency`.
            depender_module_name: The name of the module that depends on the
                target dependency.

        Returns:
            A `list` of `struct` values as returned by `bzl_selects.new`
            representing the labels for the target dependency.
        """
        if target_dep.by_name:
            # GH194: A byName reference can be a product or a module.
            # This should look for a matching product first. Then, look for a
            # module directly?
            condition = target_dep.by_name.condition
            module = deps_indexes.resolve_module_with_ctx(
                pkg_ctx.deps_index_ctx,
                target_dep.by_name.name,
            )

            # Seeing Package.swift files with byName dependencies that
            # cannot be resolved (i.e., they do not exist).
            # Example `protoc-gen-swift` in
            # `https://github.com/grpc/grpc-swift.git`.
            modules = [module] if module != None else []

        elif target_dep.target:
            condition = target_dep.target.condition
            module = deps_indexes.resolve_module_with_ctx(
                pkg_ctx.deps_index_ctx,
                target_dep.target.target_name,
            )
            if module == None:
                fail("""\
Unable to resolve target reference target dependency for {module_name}.\
""".format(module_name = target_dep.target.target_name))
            modules = [module]

        elif target_dep.product:
            condition = target_dep.product.condition
            prod_ref = target_dep.product
            dep = pkginfo_dependencies.get_by_name(
                pkg_ctx.pkg_info.dependencies,
                prod_ref.dep_name,
            )
            if dep == None:
                fail("""\
Did not find external dependency with name/identity {}.\
""".format(prod_ref.dep_name))

            product = deps_indexes.find_product(
                deps_index = pkg_ctx.deps_index_ctx.deps_index,
                identity = dep.identity,
                name = prod_ref.product_name,
            )
            if product == None:
                fail("""\
Unable to resolve product reference target dependency for product {prod_name} provided by {dep_name}.
""".format(
                    prod_name = prod_ref.product_name,
                    dep_name = prod_ref.dep_name,
                ))
            modules = deps_indexes.modules_for_product(
                deps_index = pkg_ctx.deps_index_ctx.deps_index,
                product = product,
            )

        else:
            fail("""\
Unrecognized target dependency while generating a Bazel dependency label.\
""")

        # Find the depender module
        depender_module = deps_indexes.resolve_module_with_ctx(
            pkg_ctx.deps_index_ctx,
            depender_module_name,
        )
        if depender_module == None:
            fail("Unable to find depender module named {}.".format(depender_module_name))

        labels = lists.flatten([
            deps_indexes.labels_for_module(module, depender_module.src_type)
            for module in modules
        ])

        return bzl_selects.new_from_target_dependency_condition(
            kind = _target_dep_kind,
            labels = [
                bazel_labels.normalize(label)
                for label in labels
            ],
            condition = condition,
        )

    return struct(
        bzl_select_list = _bzl_select_list,
        target_dep_kind = _target_dep_kind,
    )

pkginfo_target_deps = make_pkginfo_target_deps(
    bazel_labels = bazel_labels,
)
