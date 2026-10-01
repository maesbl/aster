#!/usr/bin/env python3
"""Generate the standalone Xcode project without external generators."""
from pathlib import Path
import hashlib, json, os, plistlib, shutil

root = Path(__file__).resolve().parent
objects = {}
def ident(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def add(object_name, **value):
    key = ident(object_name); objects[key] = value; return key
def ref(path, kind): return add('ref:'+path, isa='PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>')
source_refs, source_builds = [], []
for path in sorted(root.joinpath('Sources').glob('*.swift')):
    r = ref('Sources/'+path.name, 'sourcecode.swift'); source_refs.append(r)
    source_builds.append(add('build:'+path.name, isa='PBXBuildFile', fileRef=r))
for path in sorted(root.parent.joinpath('Aster-macOS/Shared').glob('*.swift')):
    r = ref('../Aster-macOS/Shared/'+path.name, 'sourcecode.swift'); source_refs.append(r)
    source_builds.append(add('build:'+path.name, isa='PBXBuildFile', fileRef=r))
assets = ref('Assets.xcassets', 'folder.assetcatalog')
privacy = ref('PrivacyInfo.xcprivacy', 'text.xml')
product = add('product', isa='PBXFileReference', explicitFileType='wrapper.application', path='Aster Remote.app', sourceTree='BUILT_PRODUCTS_DIR')
products = add('products', isa='PBXGroup', children=[product], name='Products', sourceTree='<group>')
group = add('root', isa='PBXGroup', children=source_refs+[assets,privacy,products], sourceTree='<group>')
sources = add('sources', isa='PBXSourcesBuildPhase', buildActionMask=2147483647, files=source_builds, runOnlyForDeploymentPostprocessing=0)
resources = add('resources', isa='PBXResourcesBuildPhase', buildActionMask=2147483647, files=[add('asset-build',isa='PBXBuildFile',fileRef=assets),add('privacy-build',isa='PBXBuildFile',fileRef=privacy)], runOnlyForDeploymentPostprocessing=0)
frameworks = add('frameworks', isa='PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
target_configs, project_configs = [], []
for mode in ['Debug','Release']:
    settings = dict(PRODUCT_BUNDLE_IDENTIFIER=os.environ.get('ASTER_IOS_BUNDLE_ID', 'com.aster.remote'), DEVELOPMENT_TEAM=os.environ.get('ASTER_APPLE_TEAM', ''), PRODUCT_NAME='Aster Remote', INFOPLIST_FILE='Info.plist',
        SWIFT_VERSION='5.0', IPHONEOS_DEPLOYMENT_TARGET='17.0', SDKROOT='iphoneos', TARGETED_DEVICE_FAMILY='1',
        CODE_SIGN_STYLE='Automatic', ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon', CURRENT_PROJECT_VERSION='9', MARKETING_VERSION='0.6.0',
        SUPPORTED_PLATFORMS='iphoneos iphonesimulator', SUPPORTS_MACCATALYST='NO', ENABLE_USER_SCRIPT_SANDBOXING='YES',
        GENERATE_INFOPLIST_FILE='NO', SWIFT_OPTIMIZATION_LEVEL='-Onone' if mode=='Debug' else '-O',
        SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG' if mode=='Debug' else '', DEBUG_INFORMATION_FORMAT='dwarf' if mode=='Debug' else 'dwarf-with-dsym')
    target_configs.append(add('target:'+mode, isa='XCBuildConfiguration',name=mode,buildSettings=settings))
    project_configs.append(add('project:'+mode, isa='XCBuildConfiguration',name=mode,buildSettings=dict(CLANG_ENABLE_MODULES='YES',ONLY_ACTIVE_ARCH='YES' if mode=='Debug' else 'NO')))
target_list = add('target-configs',isa='XCConfigurationList',buildConfigurations=target_configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
project_list = add('project-configs',isa='XCConfigurationList',buildConfigurations=project_configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
target=add('target', isa='PBXNativeTarget',buildConfigurationList=target_list,buildPhases=[sources,frameworks,resources],buildRules=[],dependencies=[],name='AsterRemote',productName='Aster Remote',productReference=product,productType='com.apple.product-type.application')
project=add('project',isa='PBXProject',attributes={'LastUpgradeCheck':'2700','TargetAttributes':{target:{'CreatedOnToolsVersion':'27.0'}}},buildConfigurationList=project_list,compatibilityVersion='Xcode 14.0',developmentRegion='es',hasScannedForEncodings=0,knownRegions=['es','en','Base'],mainGroup=group,productRefGroup=products,projectDirPath='',projectRoot='',targets=[target])
folder=root/'AsterRemote.xcodeproj';folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_bytes(plistlib.dumps(dict(archiveVersion='1',classes={},objectVersion='56',objects=objects,rootObject=project)))
scheme=folder/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
ref_xml=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Aster Remote.app" BlueprintName="AsterRemote" ReferencedContainer="container:AsterRemote.xcodeproj"/>'
(scheme/'AsterRemote.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref_xml}</BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref_xml}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref_xml}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print('AsterRemote.xcodeproj preparado.')
