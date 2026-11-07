import os, sys

root = sys.argv[1]
N = {}
names = ["PROJ","MAIN","PRODS","SYNC_APP","SYNC_TEST","REF_APP","REF_TEST","T_APP","T_TEST",
         "SRC_APP","FW_APP","RES_APP","SRC_TEST","FW_TEST","RES_TEST","PROXY","DEP",
         "CL_PROJ","CL_APP","CL_TEST","XCC","CFG_GROUP","C_PROJ_D","C_PROJ_R","C_APP_D","C_APP_R","C_TEST_D","C_TEST_R"]
for i, n in enumerate(names, 1):
    N[n] = "0A1B2C3D4E5F6A7B8C9D%04X" % i

proj_common = """				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 18.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				SDKROOT = iphoneos;
"""
proj_debug = proj_common + """				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
"""
proj_release = proj_common + """				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
"""
app = """				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "One or Many";
				INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.educational-games";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				INFOPLIST_KEY_UIUserInterfaceStyle = Light;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = "$(APP_BUNDLE_ID)";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
"""
test = """				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				GENERATE_INFOPLIST_FILE = YES;
				PRODUCT_BUNDLE_IDENTIFIER = "$(APP_BUNDLE_ID)Tests";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/OneOrMany.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/OneOrMany";
"""

def cfg(id_, name, body, base=None):
    baseline = f"\t\t\tbaseConfigurationReference = {base} /* Signing.xcconfig */;\n" if base else ""
    return f"""		{id_} /* {name} */ = {{
			isa = XCBuildConfiguration;
{baseline}			buildSettings = {{
{body}			}};
			name = {name};
		}};
"""

def phase(id_, isa, name):
    return f"""		{id_} /* {name} */ = {{
			isa = {isa};
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""

def cl(id_, d, r, label):
    return f"""		{id_} /* Build configuration list for {label} */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{d} /* Debug */,
				{r} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
"""

out = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 77;
	objects = {{

/* Begin PBXContainerItemProxy section */
		{N['PROXY']} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {N['PROJ']} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {N['T_APP']};
			remoteInfo = OneOrMany;
		}};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
		{N['REF_APP']} /* OneOrMany.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = OneOrMany.app; sourceTree = BUILT_PRODUCTS_DIR; }};
		{N['REF_TEST']} /* OneOrManyTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = OneOrManyTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
		{N['XCC']} /* Signing.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Signing.xcconfig; sourceTree = "<group>"; }};
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		{N['SYNC_APP']} /* OneOrMany */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			path = OneOrMany;
			sourceTree = "<group>";
		}};
		{N['SYNC_TEST']} /* OneOrManyTests */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			path = OneOrManyTests;
			sourceTree = "<group>";
		}};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
{phase(N['FW_APP'], 'PBXFrameworksBuildPhase', 'Frameworks')}{phase(N['FW_TEST'], 'PBXFrameworksBuildPhase', 'Frameworks')}/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{N['MAIN']} = {{
			isa = PBXGroup;
			children = (
				{N['SYNC_APP']} /* OneOrMany */,
				{N['SYNC_TEST']} /* OneOrManyTests */,
				{N['CFG_GROUP']} /* Config */,
				{N['PRODS']} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{N['CFG_GROUP']} /* Config */ = {{
			isa = PBXGroup;
			children = (
				{N['XCC']} /* Signing.xcconfig */,
			);
			path = Config;
			sourceTree = "<group>";
		}};
		{N['PRODS']} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{N['REF_APP']} /* OneOrMany.app */,
				{N['REF_TEST']} /* OneOrManyTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{N['T_APP']} /* OneOrMany */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {N['CL_APP']} /* Build configuration list for PBXNativeTarget "OneOrMany" */;
			buildPhases = (
				{N['SRC_APP']} /* Sources */,
				{N['FW_APP']} /* Frameworks */,
				{N['RES_APP']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				{N['SYNC_APP']} /* OneOrMany */,
			);
			name = OneOrMany;
			packageProductDependencies = (
			);
			productName = OneOrMany;
			productReference = {N['REF_APP']} /* OneOrMany.app */;
			productType = "com.apple.product-type.application";
		}};
		{N['T_TEST']} /* OneOrManyTests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {N['CL_TEST']} /* Build configuration list for PBXNativeTarget "OneOrManyTests" */;
			buildPhases = (
				{N['SRC_TEST']} /* Sources */,
				{N['FW_TEST']} /* Frameworks */,
				{N['RES_TEST']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				{N['DEP']} /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				{N['SYNC_TEST']} /* OneOrManyTests */,
			);
			name = OneOrManyTests;
			packageProductDependencies = (
			);
			productName = OneOrManyTests;
			productReference = {N['REF_TEST']} /* OneOrManyTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{N['PROJ']} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2700;
				LastUpgradeCheck = 2700;
				TargetAttributes = {{
					{N['T_APP']} = {{
						CreatedOnToolsVersion = 27.0;
					}};
					{N['T_TEST']} = {{
						CreatedOnToolsVersion = 27.0;
						TestTargetID = {N['T_APP']};
					}};
				}};
			}};
			buildConfigurationList = {N['CL_PROJ']} /* Build configuration list for PBXProject "OneOrMany" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {N['MAIN']};
			minimizedProjectReferenceProxies = 1;
			preferredProjectObjectVersion = 77;
			productRefGroup = {N['PRODS']} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{N['T_APP']} /* OneOrMany */,
				{N['T_TEST']} /* OneOrManyTests */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
{phase(N['RES_APP'], 'PBXResourcesBuildPhase', 'Resources')}{phase(N['RES_TEST'], 'PBXResourcesBuildPhase', 'Resources')}/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
{phase(N['SRC_APP'], 'PBXSourcesBuildPhase', 'Sources')}{phase(N['SRC_TEST'], 'PBXSourcesBuildPhase', 'Sources')}/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		{N['DEP']} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {N['T_APP']} /* OneOrMany */;
			targetProxy = {N['PROXY']} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
{cfg(N['C_PROJ_D'], 'Debug', proj_debug)}{cfg(N['C_PROJ_R'], 'Release', proj_release)}{cfg(N['C_APP_D'], 'Debug', app, N['XCC'])}{cfg(N['C_APP_R'], 'Release', app, N['XCC'])}{cfg(N['C_TEST_D'], 'Debug', test, N['XCC'])}{cfg(N['C_TEST_R'], 'Release', test, N['XCC'])}/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
{cl(N['CL_PROJ'], N['C_PROJ_D'], N['C_PROJ_R'], 'PBXProject "OneOrMany"')}{cl(N['CL_APP'], N['C_APP_D'], N['C_APP_R'], 'PBXNativeTarget "OneOrMany"')}{cl(N['CL_TEST'], N['C_TEST_D'], N['C_TEST_R'], 'PBXNativeTarget "OneOrManyTests"')}/* End XCConfigurationList section */
	}};
	rootObject = {N['PROJ']} /* Project object */;
}}
"""

pdir = os.path.join(root, "OneOrMany.xcodeproj")
os.makedirs(os.path.join(pdir, "xcshareddata", "xcschemes"), exist_ok=True)
with open(os.path.join(pdir, "project.pbxproj"), "w") as f:
    f.write(out)

scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2700" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{N['T_APP']}" BuildableName = "OneOrMany.app" BlueprintName = "OneOrMany" ReferencedContainer = "container:OneOrMany.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO" parallelizable = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{N['T_TEST']}" BuildableName = "OneOrManyTests.xctest" BlueprintName = "OneOrManyTests" ReferencedContainer = "container:OneOrMany.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{N['T_APP']}" BuildableName = "OneOrMany.app" BlueprintName = "OneOrMany" ReferencedContainer = "container:OneOrMany.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
with open(os.path.join(pdir, "xcshareddata", "xcschemes", "OneOrMany.xcscheme"), "w") as f:
    f.write(scheme)
print("ok")
