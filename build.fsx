// include Fake libs
#r "tools/FAKE/FakeLib.dll"

open Fake

// Directories
let buildDir  = "./build/"
let testDir   = "./test/"
let deployDir = "./deploy/"

// tools
let fxCopRoot = "./Tools/FxCop/FxCopCmd.exe"

// Filesets
let appReferences  = !! "src/**/*.csproj" 

let testReferences = !! "src/*.Tests/*.csproj"

// version info
let version = "0.2"  // or retrieve from CI server

// Targets
Target "Clean" (fun _ -> 
    CleanDirs [buildDir; testDir; deployDir]
)

Target "BuildApp" (fun _ ->
    // compile all projects below src/app/
    MSBuildReleaseExt buildDir ["Configuration","Release"; "Platform","x64"] "Build" appReferences
        |> Log "AppBuild-Output: "
)

Target "BuildTest" (fun _ ->
    MSBuildDebug testDir "Build" testReferences
        |> Log "TestBuild-Output: "
)

Target "NUnitTest" (fun _ ->  
    !! (testDir + "/NUnit.Test.*.dll")
        |> NUnit (fun p -> 
            {p with
                DisableShadowCopy = true; 
                OutputFile = testDir + "TestResults.xml"})
)

Target "xUnitTest" (fun _ ->  
    !! (testDir + "/*.Tests.dll")
        |> xUnit (fun p -> 
            {p with 
                ShadowCopy = false;
                HtmlOutput = true;
                XmlOutput = true;
                OutputDir = testDir })
)

Target "FxCop" (fun _ ->
    !! (buildDir + "/**/*.dll") 
        ++ (buildDir + "/**/*.exe")
        |> FxCop (fun p -> 
            {p with                     
                ReportFileName = testDir + "FXCopResults.xml";
                ToolPath = fxCopRoot})
)

Target "Deploy" (fun _ ->
    !! (buildDir + "/**/*.*") 
        -- "*.zip" 
        |> Zip buildDir (deployDir + "PerfTap-E." + version + ".zip")
)

// Build order
"Clean"
  ==> "BuildApp"
  ==> "BuildTest"
  ==> "FxCop"
  ==> "xUnitTest"
  //=?> ("xUnitTest",hasBuildParam "xUnitTest")  // runs the target only if FAKE was called with parameter xUnitTest
  ==> "Deploy"

// start build
RunTargetOrDefault "Deploy"