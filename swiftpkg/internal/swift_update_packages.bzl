"""Defines the `swift_update_packages` macro."""

load("@bazel_gazelle//:def.bzl", _gazelle = "gazelle")

def swift_update_packages(
        name,
        gazelle,
        package_manifest = "Package.swift",
        swift_deps = "swift_deps.bzl",
        swift_deps_fn = "swift_dependencies",
        swift_deps_index = "swift_deps_index.json",
        **kwargs):
    """Defines gazelle update-repos targets that are used to resolve and update \
    Swift package dependencies.

    Args:
        name: The name of the `resolve` target as a `string`. The target name
            for the `update` target is derived from this value by appending
            `_to_latest`.
        gazelle: The label to `gazelle_binary` that includes the `swift_bazel`
            Gazelle extension.
        package_manifest: Optional. The name of the Swift package manifest file
            as a `string`.
        swift_deps: Optional. The name of the Starlark file that should be
            updated with the Swift package dependencies as a `string`.
        swift_deps_fn: Optional. The name of the Starlark function in the
            `swift_deps` file that should be updated with the Swift package
            dependencies as a `string`.
        swift_deps_index: Optional. The relative path to the Swift
            dependencies index JSON file. This path is relative to the
            repository root, not the location of this declaration.
        **kwargs: Attributes that are passed along to the gazelle declarations.
    """
    _SWIFT_UPDATE_REPOS_ARGS = [
        "-from_file={}".format(package_manifest),
        "-to_macro={swift_deps}%{swift_deps_fn}".format(
            swift_deps = swift_deps,
            swift_deps_fn = swift_deps_fn,
        ),
        "-prune",
        "-swift_dependency_index={}".format(swift_deps_index),
    ]

    _gazelle(
        name = name,
        args = _SWIFT_UPDATE_REPOS_ARGS,
        command = "update-repos",
        gazelle = gazelle,
        **kwargs
    )

    _gazelle(
        name = name + "_to_latest",
        args = _SWIFT_UPDATE_REPOS_ARGS + [
            "-swift_update_packages_to_latest",
        ],
        command = "update-repos",
        gazelle = gazelle,
        **kwargs
    )
