#!/usr/bin/env python3
"""Create the small, self-contained Xcode project without external generators."""
from pathlib import Path
from hashlib import sha1

root = Path(__file__).resolve().parents[1]
project = root / "MCVNot.xcodeproj"
project.mkdir(exist_ok=True)
team_id = "P5Q772DRZW"

def ident(name):
    return sha1(name.encode()).hexdigest()[:24].upper()

objects = {}
def add(name, value):
    key = ident(name)
    objects[key] = value
    return key

def q(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'

def arr(values):
    return "( " + ", ".join(values) + ", )" if values else "()"

project_id = ident("project")
app_target = ident("app target")
widget_target = ident("widget target")

app_sources = sorted(str(p.relative_to(root)) for p in (root / "App").glob("*.swift"))
app_resources = ["App/Resources/AppIcon.icns"]
shared_sources = ["Shared/Assignment.swift", "Shared/AssignmentStore.swift"]
widget_sources = ["Widget/MCVWidget.swift"]
other_files = ["App/Info.plist", "App/MCVNot.entitlements",
               "Widget/Info.plist", "Widget/MCVWidget.entitlements"]

refs = {}
for path in app_sources + shared_sources + widget_sources + other_files + app_resources:
    filetype = "sourcecode.swift" if path.endswith(".swift") else "image.icns" if path.endswith(".icns") else "text.plist.xml"
    refs[path] = add("file " + path, "{ isa = PBXFileReference; lastKnownFileType = " + filetype +
                     "; path = " + q(Path(path).name) + "; sourceTree = \"<group>\"; }")

app_product = add("app product", "{ isa = PBXFileReference; explicitFileType = wrapper.application; "
                  "includeInIndex = 0; path = MCVNot.app; sourceTree = BUILT_PRODUCTS_DIR; }")
widget_product = add("widget product", "{ isa = PBXFileReference; explicitFileType = wrapper.app-extension; "
                     "includeInIndex = 0; path = MCVWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }")

def group(name, children):
    return add("group " + name, "{ isa = PBXGroup; children = " + arr(children) +
               "; path = " + q(name) + "; sourceTree = \"<group>\"; }")

resource_group = group("Resources", [refs[p] for p in app_resources])
app_group = group("App", [refs[p] for p in app_sources + other_files[:2]] + [resource_group])
shared_group = group("Shared", [refs[p] for p in shared_sources])
widget_group = group("Widget", [refs[p] for p in widget_sources + other_files[2:]])
products_group = add("products group", "{ isa = PBXGroup; children = " +
                     arr([app_product, widget_product]) + "; name = Products; sourceTree = \"<group>\"; }")
main_group = add("main group", "{ isa = PBXGroup; children = " +
                 arr([app_group, shared_group, widget_group, products_group]) +
                 "; sourceTree = \"<group>\"; }")

def source_phase(name, paths):
    files = []
    for path in paths:
        files.append(add(name + " build " + path, "{ isa = PBXBuildFile; fileRef = " + refs[path] + "; }"))
    return add(name + " sources", "{ isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; "
               "files = " + arr(files) + "; runOnlyForDeploymentPostprocessing = 0; }")

resource_files = [add("app resource " + p, "{ isa = PBXBuildFile; fileRef = " + refs[p] + "; }")
                  for p in app_resources]
resource_phase = add("app resources", "{ isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; "
                     "files = " + arr(resource_files) + "; runOnlyForDeploymentPostprocessing = 0; }")
app_phase = source_phase("app", app_sources + shared_sources)
widget_phase = source_phase("widget", widget_sources + shared_sources)
embed_file = add("embed widget", "{ isa = PBXBuildFile; fileRef = " + widget_product +
                 "; settings = { ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; }")
embed_phase = add("embed phase", "{ isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; "
                  "dstPath = \"\"; dstSubfolderSpec = 13; files = " + arr([embed_file]) +
                  "; name = \"Embed App Extensions\"; runOnlyForDeploymentPostprocessing = 0; }")
proxy = add("widget proxy", "{ isa = PBXContainerItemProxy; containerPortal = " + project_id +
            "; proxyType = 1; remoteGlobalIDString = " + widget_target +
            "; remoteInfo = MCVWidget; }")
dependency = add("widget dependency", "{ isa = PBXTargetDependency; target = " + widget_target +
                 "; targetProxy = " + proxy + "; }")

def config(name, build_settings):
    settings = " ".join(k + " = " + q(v) + ";" for k, v in build_settings.items())
    return add(name, "{ isa = XCBuildConfiguration; buildSettings = { " + settings +
               " }; name = " + name.split()[-1] + "; }")

project_settings = {"SDKROOT": "macosx", "MACOSX_DEPLOYMENT_TARGET": "14.0",
                    "SWIFT_VERSION": "5.0", "CLANG_ENABLE_MODULES": "YES",
                    "SUPPORTED_PLATFORMS": "macosx"}
app_settings = {"CODE_SIGN_ENTITLEMENTS": "App/MCVNot.entitlements",
                "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": team_id,
                "INFOPLIST_FILE": "App/Info.plist",
                "PRODUCT_BUNDLE_IDENTIFIER": "com.mcvnot.app", "PRODUCT_NAME": "MCVNot",
                "SWIFT_VERSION": "5.0", "MACOSX_DEPLOYMENT_TARGET": "14.0",
                "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks"}
widget_settings = {"APPLICATION_EXTENSION_API_ONLY": "YES",
                   "CODE_SIGN_ENTITLEMENTS": "Widget/MCVWidget.entitlements",
                   "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": team_id,
                   "INFOPLIST_FILE": "Widget/Info.plist",
                   "PRODUCT_BUNDLE_IDENTIFIER": "com.mcvnot.app.widget.v2", "PRODUCT_NAME": "MCVWidget",
                   "SKIP_INSTALL": "YES", "SWIFT_VERSION": "5.0",
                   "MACOSX_DEPLOYMENT_TARGET": "14.0",
                   "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks @executable_path/../../../../Frameworks"}

def config_list(name, settings):
    debug = config(name + " Debug", settings | {"SWIFT_OPTIMIZATION_LEVEL": "-Onone", "DEBUG_INFORMATION_FORMAT": "dwarf"})
    release = config(name + " Release", settings | {"SWIFT_OPTIMIZATION_LEVEL": "-O", "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym"})
    return add(name + " configurations", "{ isa = XCConfigurationList; buildConfigurations = " +
               arr([debug, release]) + "; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }")

project_configs = config_list("project", project_settings)
app_configs = config_list("app", app_settings)
widget_configs = config_list("widget", widget_settings)

objects[app_target] = ("{ isa = PBXNativeTarget; buildConfigurationList = " + app_configs +
    "; buildPhases = " + arr([app_phase, resource_phase, embed_phase]) +
    "; buildRules = (); dependencies = " + arr([dependency]) +
    "; name = MCVNot; productName = MCVNot; productReference = " + app_product +
    "; productType = \"com.apple.product-type.application\"; }")
objects[widget_target] = ("{ isa = PBXNativeTarget; buildConfigurationList = " + widget_configs +
    "; buildPhases = " + arr([widget_phase]) +
    "; buildRules = (); dependencies = (); name = MCVWidget; productName = MCVWidget; productReference = " +
    widget_product + "; productType = \"com.apple.product-type.app-extension\"; }")
objects[project_id] = ("{ isa = PBXProject; attributes = { LastUpgradeCheck = 1500; }; buildConfigurationList = " +
    project_configs + "; compatibilityVersion = \"Xcode 15.0\"; developmentRegion = th; hasScannedForEncodings = 0; " +
    "knownRegions = (th, en, Base, ); mainGroup = " + main_group + "; productRefGroup = " + products_group +
    "; projectDirPath = \"\"; projectRoot = \"\"; targets = " + arr([app_target, widget_target]) + "; }")

body = "// !$*UTF8*$!\n{\n archiveVersion = 1;\n classes = {};\n objectVersion = 60;\n objects = {\n"
body += "\n".join("  " + key + " = " + objects[key] + ";" for key in sorted(objects))
body += "\n };\n rootObject = " + project_id + ";\n}\n"
(project / "project.pbxproj").write_text(body)
scheme_dir = project / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries>
      <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="MCVNot.app" BlueprintName="MCVNot" ReferencedContainer="container:MCVNot.xcodeproj"/>
      </BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="MCVNot.app" BlueprintName="MCVNot" ReferencedContainer="container:MCVNot.xcodeproj"/>
    </BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="MCVNot.app" BlueprintName="MCVNot" ReferencedContainer="container:MCVNot.xcodeproj"/>
    </BuildableProductRunnable>
  </ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
(scheme_dir / "MCVNot.xcscheme").write_text(scheme)
print(project / "project.pbxproj")
