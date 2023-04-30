# https://github.com/facebookincubator/reindeer/blob/c78947234f5b61d5b8e56831c75790bb326a28c9/example/third-party/macros/rust_third_party.bzl

# @nolint

load(":iterable.bzl", "iterable")
load(":new_sets.bzl", "sets")
load(":type_defs.bzl", "is_dict")

# Get current target platform - hard-coded for example, matches one of the platforms
# defined in reindeer.toml.
def _get_plat():
    return "linux-x86_64"

# Matching host triple
def _get_native_host_triple():
    return "x86_64-unknown-linux-gnu"

def extend(orig, new):
    if orig == None:
        ret = new
    elif new == None:
        ret = orig
    elif is_dict(orig):
        ret = orig.copy()
        ret.update(new)
    else:  # list
        ret = orig + new
    return ret

# Invoke something with a default cargo-like environment. This is used to invoke buildscripts
# from within a Buck rule to get it to do whatever it does (typically, either emit command-line
# options for rustc, or generate some source).
def _make_preamble(out_dir, package_name, version, features, cfgs, env, target_override):
    # Work out what rustc to pass to the script
    rustc = native.read_config("rust", "compiler", "rustc")
    if "//" in rustc:
        rustc = "(exe %s)" % rustc

    # CWD of a genrule script is the source directory but use $SRCDIR to make it an absolute path
    return """
        mkdir -p {out_dir}; \
        env \
            CARGO_MANIFEST_DIR=$SRCDIR/vendor/{package_name}-{version} \
            RUST_BACKTRACE=1 \
            OUT_DIR={out_dir} \
            CARGO=/bin/false \
            {features} \
            {cfgs} \
            CARGO_PKG_NAME={package_name} \
            CARGO_PKG_VERSION={version} \
            TARGET={target} \
            HOST={host} \
            RUSTC={rustc} \
            RUSTC_LINKER=/bin/false \
            `{rustc} --print cfg | awk -f $(location //third-party/macros:cargo_cfgs.awk)` \
            {env} \
    """.format(
        out_dir = out_dir,
        package_name = package_name,
        version = version,
        features = " ".join(["CARGO_FEATURE_{}=1".format(feature.upper().replace("-", "_")) for feature in features]),
        cfgs = " ".join(["CARGO_CFG_{}=1".format(cfg.upper().replace("-", "_")) for cfg in cfgs]),
        target = target_override or _get_native_host_triple(),
        host = _get_native_host_triple(),
        rustc = rustc,
        env = "\\\n".join(["'{}'='{}'".format(var, val) for var, val in env.items()]),
    )

# Invoke a Rust buildscript binary with the right surrounding
# environment variables. `filters` is a shell command which takes the
# output of the build script and filters appropriately. It is given the
# final output file path on its commandline.
def rust_buildscript_genrule_args(name, buildscript_rule, outfile, package_name, version, filter, features = [], cfgs = [], env = {}, target = None):
    pre = _make_preamble("\\$(dirname $OUT)", package_name, version, features, cfgs, env, target)
    native.cxx_genrule(
        name = name,
        out = outfile,
        cmd = pre + "$(exe {buildscript}) | {filter} > $OUT".format(
            buildscript = buildscript_rule,
            filter = filter,
        ),
    )

# Invoke a build script for its generated sources.
def rust_buildscript_genrule_srcs(name, buildscript_rule, files, package_name, version, features = [], cfgs = [], env = {}, target = None, srcs = []):
    pre = _make_preamble("$OUT", package_name, version, features, cfgs, env, target)
    native.cxx_genrule(
        name = name,
        srcs = srcs,
        cmd = pre + "$(exe {buildscript})".format(
            buildscript = buildscript_rule,
        ),
        outs = {file: [file] for file in files},
    )

# Add platform-specific args to args for a given platform. This assumes there's some static configuration
# for target platform (_get_plat) which isn't very flexible. A better approach would be to construct
# srcs/deps/etc with `select` to conditionally configure each target, but that's out of scope for this.
def platform_attrs(platformname, platformattrs, attrs):
    for attr in sets.to_list(sets.make(iterable.concat(attrs.keys(), platformattrs.get(platformname, {}).keys()))):
        new = extend(attrs.get(attr), platformattrs.get(platformname, {}).get(attr))
        attrs[attr] = new
    return attrs

def third_party_rust_library(name, platform = {}, dlopen_enable = False, python_ext = None, **kwargs):
    # This works around a bug in Buck, which complains if srcs is missing - but that can happen if all
    # the sources are mapped_srcs
    if "srcs" not in kwargs:
        kwargs["srcs"] = []

    # Rust crates which are python extensions need special handling to make sure they get linked
    # properly. This is not enough on its own - it still assumes there's a dependency on the python
    # library.
    if dlopen_enable or python_ext:
        # This is all pretty ELF/Linux-specific
        linker_flags = ["-shared"]
        if python_ext:
            linker_flags.append("-uPyInit_{}".format(python_ext))
            kwargs["preferred_linkage"] = "static"
        native.cxx_binary(name = name + "-so", link_style = "static_pic", linker_flags = linker_flags, deps = [":" + name])

    native.rust_library(name=name, **platform_attrs(_get_plat(), platform, kwargs))

# `platform` is a map from a platform (defined in reindeer.toml) to the attributes
# specific to that platform.
def third_party_rust_binary(name, platform = {}, **kwargs):
    # This works around a bug in Buck, which complains if srcs is missing - but that can happen if all
    # the sources are mapped_srcs
    if "srcs" not in kwargs:
        kwargs["srcs"] = []
    native.rust_binary(name=name, **platform_attrs(_get_plat(), platform, kwargs))

def third_party_rust_cxx_library(name, **kwargs):
    native.cxx_library(name, **kwargs)

def third_party_rust_prebuilt_cxx_library(name, **kwargs):
    native.prebuilt_cxx_library(name, **kwargs)
