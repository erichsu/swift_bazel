# This was lifted directly from
# https://github.com/bazelbuild/rules_swift/blob/master/swift/internal/module_maps.bzl

# Copyright 2020 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Logic for generating Clang module map files."""

# NOTE(cgrindel): Mangled the prefix to avoid finding this when looking for temporary task comments.
# T-O-D-O(#723): Remove these disables once https://github.com/bazelbuild/buildtools/issues/926 is fixed
# buildifier: disable=return-value
# buildifier: disable=function-docstring-return
def write_module_map(
        actions,
        module_map_file,
        module_name,
        dependent_module_names = [],
        exported_module_ids = [],
        public_headers = [],
        public_textual_headers = [],
        private_headers = [],
        private_textual_headers = [],
        umbrella_header = None,
        workspace_relative = False):
    """Writes the content of the module map to a file.

    Args:
        actions: The actions object from the aspect context.
        module_map_file: A `File` representing the module map being written.
        module_name: The name of the module being generated.
        dependent_module_names: A `list` of names of Clang modules that are
            direct dependencies of the target whose module map is being written.
        exported_module_ids: A `list` of Clang wildcard module identifiers that
            will be re-exported as part of the API of the module being written.
            The values in this list should match `wildcard-module-id` as
            described by
            https://clang.llvm.org/docs/Modules.html#export-declaration. Common
            values include the empty list to re-export nothing (except the
            module's own API), or `["*"]` to re-export all modules that were
            imported by the header files in the module.
        public_headers: The `list` of `File`s representing the public modular
            headers of the target whose module map is being written.
        public_textual_headers: The `list` of `File`s representing the public
            textual headers of the target whose module map is being written.
        private_headers: The `list` of `File`s representing the private modular
            headers of the target whose module map is being written.
        private_textual_headers: The `list` of `File`s representing the private
            textual headers of the target whose module map is being written.
        umbrella_header: A `File` representing an umbrella header that, if
            present, will be written into the module map instead of the list of
            headers in the compilation context.
        workspace_relative: A Boolean value indicating whether the header paths
            written in the module map file should be relative to the workspace
            or relative to the module map file.
    """

    # In the non-workspace-relative case, precompute the relative-to-dir and the
    # repeated `../` string used to go back up to the workspace root instead of
    # recomputing it every time a header path is written.
    if workspace_relative:
        relative_to_dir = None
        back_to_root_path = None
    else:
        relative_to_dir = module_map_file.dirname
        back_to_root_path = "../" * len(relative_to_dir.split("/"))

    content = actions.args()
    content.set_param_file_format("multiline")

    content.add(module_name, format = 'module "%s" {')

    # Write an `export` declaration for each of the module identifiers that
    # should be re-exported by this module.
    content.add_all(exported_module_ids, format_each = "    export %s")
    content.add("")

    def _relativized_header_paths(file_or_dir, directory_expander):
        return [
            _header_path(
                header_file = file,
                relative_to_dir = relative_to_dir,
                back_to_root_path = back_to_root_path,
            )
            for file in directory_expander.expand(file_or_dir)
        ]

    def _add_headers(*, headers, kind):
        content.add_all(
            headers,
            allow_closure = True,
            format_each = '    {} "%s"'.format(kind),
            map_each = _relativized_header_paths,
        )

    if umbrella_header:
        _add_headers(headers = [umbrella_header], kind = "umbrella header")
    else:
        _add_headers(headers = public_headers, kind = "header")
        _add_headers(headers = private_headers, kind = "private header")
        _add_headers(headers = public_textual_headers, kind = "textual header")
        _add_headers(
            headers = private_textual_headers,
            kind = "private textual header",
        )

    content.add("")

    # Write a `use` declaration for each of the module's dependencies.
    content.add_all(dependent_module_names, format_each = '    use "%s"')
    content.add("}")

    actions.write(
        content = content,
        output = module_map_file,
    )

def _header_path(header_file, relative_to_dir, back_to_root_path):
    """Returns the path to a header file to be written in the module map.

    Args:
        header_file: A `File` representing the header whose path should be
            returned.
        relative_to_dir: A `File` representing the module map being
            written, which is used during path relativization if necessary. If
            this is `None`, then no relativization is performed of the header
            path and the workspace-relative path is used instead.
        back_to_root_path: A path string consisting of repeated `../` segments
            that should be used to return from the module map's directory to the
            workspace root. This should be `None` if `relative_to_dir` is
            `None`.

    Returns:
        The path to the header file, relative to either the workspace or the
        module map as requested.
    """

    # If the module map is workspace-relative, then the file's path is what we
    # want.
    if not relative_to_dir:
        return header_file.path

    # Minor optimization for the generated Objective-C header of a Swift module,
    # which will be in the same directory as the module map file -- we can just
    # use the header's basename instead of the elaborate relative path string
    # below.
    if header_file.dirname == relative_to_dir:
        return header_file.basename

    # Otherwise, since the module map is generated, we need to get the full path
    # to it rather than just its short path (that is, the path starting with
    # bazel-out/). Then, we can simply walk up the same number of parent
    # directories as there are path segments, and append the header file's path
    # to that. The `back_to_root_path` string is guaranteed to end in a slash,
    # so we use simple concatenation instead of Skylib's `paths.join` to avoid
    # extra work.
    return back_to_root_path + header_file.path
