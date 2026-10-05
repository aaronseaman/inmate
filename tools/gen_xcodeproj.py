#!/usr/bin/env python3
"""Generates FPod.xcodeproj (deterministic IDs) for the iOS app.

The app target compiles the platform-independent core (Sources/FPodCore) together
with the UIKit/SpriteKit layer (iOS/FPod). Re-run after adding or removing files:

    python3 tools/gen_xcodeproj.py
"""
import hashlib
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJ = os.path.join(ROOT, "FPod.xcodeproj")
BUNDLE_ID = "com.example.fpod"
DEPLOYMENT = "16.0"


def uid(name):
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()


def swift_files(rel_dir):
    out = []
    for base, dirs, files in os.walk(os.path.join(ROOT, rel_dir)):
        dirs.sort()
        for f in sorted(files):
            if f.endswith(".swift"):
                out.append(os.path.relpath(os.path.join(base, f), ROOT))
    return out


core = swift_files("Sources/FPodCore")
app = swift_files("iOS/FPod")
assets = "iOS/FPod/Assets.xcassets"
plist = "iOS/FPod/Info.plist"

objects = {}
build_files = []
file_refs = {}


def file_ref(path, ftype):
    fid = uid("ref:" + path)
    name = os.path.basename(path)
    objects[fid] = f'{{isa = PBXFileReference; lastKnownFileType = {ftype}; path = "{name}"; sourceTree = "<group>"; }};'
    file_refs[path] = fid
    return fid


for p in core + app:
    fid = file_ref(p, "sourcecode.swift")
    bid = uid("build:" + p)
    objects[bid] = f'{{isa = PBXBuildFile; fileRef = {fid}; }};'
    build_files.append(bid)

assets_ref = file_ref(assets, "folder.assetcatalog")
assets_build = uid("build:" + assets)
objects[assets_build] = f'{{isa = PBXBuildFile; fileRef = {assets_ref}; }};'
plist_ref = file_ref(plist, "text.plist.xml")

app_product = uid("product:FPod.app")
objects[app_product] = '{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = FPod.app; sourceTree = BUILT_PRODUCTS_DIR; };'

# Groups mirror directories.
groups = {}


def group_for(dir_path, name=None, path=None):
    key = "group:" + dir_path
    gid = uid(key)
    if gid not in groups:
        groups[gid] = {"name": name, "path": path if path is not None else os.path.basename(dir_path), "children": []}
    return gid


def add_to_tree(root_dir, files, root_name):
    root_gid = group_for(root_dir, name=root_name, path=root_dir)
    for f in files:
        rel = os.path.relpath(f, root_dir)
        parts = rel.split(os.sep)
        parent = root_gid
        cur = root_dir
        for d in parts[:-1]:
            cur = os.path.join(cur, d)
            g = group_for(cur)
            if g not in groups[parent]["children"]:
                groups[parent]["children"].append(g)
            parent = g
        groups[parent]["children"].append(file_refs[f])
    return root_gid


core_group = add_to_tree("Sources/FPodCore", core, "FPodCore")
app_group = add_to_tree("iOS/FPod", app + [assets, plist], "FPod (iOS)")
products_group = uid("group:Products")
groups[products_group] = {"name": "Products", "path": None, "children": [app_product]}
main_group = uid("group:main")
groups[main_group] = {"name": None, "path": None, "children": [app_group, core_group, products_group]}

for gid, g in groups.items():
    attrs = ["isa = PBXGroup;", "children = (" + "".join(c + ", " for c in g["children"]) + ");"]
    if g["name"]:
        attrs.append(f'name = "{g["name"]}";')
    if g["path"]:
        attrs.append(f'path = "{g["path"]}";')
    attrs.append('sourceTree = "<group>";')
    objects[gid] = "{" + " ".join(attrs) + " };"

sources_phase = uid("phase:sources")
objects[sources_phase] = "{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (" + "".join(b + ", " for b in build_files) + "); runOnlyForDeploymentPostprocessing = 0; };"
frameworks_phase = uid("phase:frameworks")
objects[frameworks_phase] = "{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };"
resources_phase = uid("phase:resources")
objects[resources_phase] = "{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (" + assets_build + ", ); runOnlyForDeploymentPostprocessing = 0; };"


def settings_block(d):
    out = []
    for k in sorted(d):
        v = d[k]
        if isinstance(v, list):
            out.append(f'{k} = (' + "".join(f'"{x}", ' for x in v) + ');')
        else:
            out.append(f'{k} = "{v}";')
    return "{" + " ".join(out) + "}"


common = {
    "ALWAYS_SEARCH_USER_PATHS": "NO", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu17", "GCC_NO_COMMON_BLOCKS": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT, "SDKROOT": "iphoneos", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
}
proj_debug = dict(common, **{
    "COPY_PHASE_STRIP": "NO", "DEBUG_INFORMATION_FORMAT": "dwarf", "ENABLE_TESTABILITY": "YES",
    "GCC_OPTIMIZATION_LEVEL": "0", "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"], "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG", "SWIFT_OPTIMIZATION_LEVEL": "-Onone", "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
})
proj_release = dict(common, **{
    "COPY_PHASE_STRIP": "NO", "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym", "ENABLE_NS_ASSERTIONS": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule", "SWIFT_OPTIMIZATION_LEVEL": "-O", "VALIDATE_PRODUCT": "YES", "MTL_ENABLE_DEBUG_INFO": "NO",
})
target_common = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1", "DEVELOPMENT_TEAM": "",
    "GENERATE_INFOPLIST_FILE": "NO", "INFOPLIST_FILE": plist,
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"], "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID, "PRODUCT_NAME": "$(TARGET_NAME)", "SWIFT_EMIT_LOC_STRINGS": "NO",
    "SWIFT_VERSION": "5.0", "TARGETED_DEVICE_FAMILY": "1", "SUPPORTS_MACCATALYST": "NO",
    "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO", "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD": "NO",
}

cfg_ids = {}
for scope, debug, release in [("project", proj_debug, proj_release), ("target", target_common, target_common)]:
    for name, d in [("Debug", debug), ("Release", release)]:
        cid = uid(f"config:{scope}:{name}")
        cfg_ids[(scope, name)] = cid
        objects[cid] = "{isa = XCBuildConfiguration; buildSettings = " + settings_block(d) + f"; name = {name}; }};"

proj_cfg_list = uid("configlist:project")
objects[proj_cfg_list] = "{isa = XCConfigurationList; buildConfigurations = (" + cfg_ids[("project", "Debug")] + ", " + cfg_ids[("project", "Release")] + ", ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };"
target_cfg_list = uid("configlist:target")
objects[target_cfg_list] = "{isa = XCConfigurationList; buildConfigurations = (" + cfg_ids[("target", "Debug")] + ", " + cfg_ids[("target", "Release")] + ", ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };"

target = uid("target:FPod")
objects[target] = ("{isa = PBXNativeTarget; buildConfigurationList = " + target_cfg_list + "; buildPhases = (" + sources_phase + ", " + frameworks_phase + ", " + resources_phase +
                   ", ); buildRules = (); dependencies = (); name = FPod; productName = FPod; productReference = " + app_product + '; productType = "com.apple.product-type.application"; };')
project = uid("project:FPod")
objects[project] = ("{isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 1500; LastUpgradeCheck = 1500; TargetAttributes = {" + target +
                    " = {CreatedOnToolsVersion = 15.0; }; }; }; buildConfigurationList = " + proj_cfg_list + '; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base, ); mainGroup = ' +
                    main_group + "; productRefGroup = " + products_group + '; projectDirPath = ""; projectRoot = ""; targets = (' + target + ", ); };")

lines = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {", "\t};", "\tobjectVersion = 56;", "\tobjects = {"]
for k in sorted(objects):
    lines.append(f"\t\t{k} = {objects[k]}")
lines += ["\t};", f"\trootObject = {project};", "}", ""]
os.makedirs(PROJ, exist_ok=True)
with open(os.path.join(PROJ, "project.pbxproj"), "w") as f:
    f.write("\n".join(lines))

scheme_dir = os.path.join(PROJ, "xcshareddata", "xcschemes")
os.makedirs(scheme_dir, exist_ok=True)
ref = f'''<BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target}"
               BuildableName = "FPod.app"
               BlueprintName = "FPod"
               ReferencedContainer = "container:FPod.xcodeproj">
            </BuildableReference>'''
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1500" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            {ref}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
            {ref}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
            {ref}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
with open(os.path.join(scheme_dir, "FPod.xcscheme"), "w") as f:
    f.write(scheme)
print(f"FPod.xcodeproj: {len(core)} core + {len(app)} app Swift files")
