	properties { 
	  $project = "PerfTap"
	  
	  $environment = ""   # handed in commmand line
	  $verbosity = "n"    # verbosity levels: q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
	  $revision = "0"     # handed in commmand line
	  $version = "1.0.0." # problem with version as substitution at this level
	 
	  $platform = "x64"
	  $config = "Release"
	  
	  $base_dir  = resolve-path .
	  $configuration = "bin\$platform\$config"
 
	  $src_dir = "$base_dir\src"
	  $lib_dir = "$base_dir\lib"
	  $tools_dir = "$base_dir\tools"

	  $output_dir = "$base_dir\output"
	  $release_dir = "$output_dir\Releases"
	  $extract_dir = "$base_dir\CodeToDeploy\Deploy"
	  $buildartifacts_dir = "$build_dir\CodeToDeploy\Publish"
	  
	  $test_runner_path = "$tools_dir\xunit.runners.1.9.2\tools\xunit.console.clr4.exe"
	  $test_runner_opts = "$output_dir\xunit.results.html"

  	  $test_dir = "$src_dir\$project.Tests\$configuration"
	  $test_path = "$output_dir\$project.Tests.dll"
	   
	  $sln_file = "$src_dir\$project.sln"
	}


	Task Clean {
        exec { msbuild $sln_file /t:clean /verbosity:$verbosity }
    }

	Task Compile  {
		exec { msbuild $sln_file /t:build "/p:Configuration=$config" "/p:Platform=$platform" /p:OutDir="$output_dir" }
	}

	Task Test -depends Compile {
		assert(Test-Path($test_runner_path)) "xUnit must be available."
		assert(Test-Path($test_path)) "PerfTap.Test Path must be available."
        Exec { cmd /C $test_runner_path $test_path /html $test_runner_opts }	
    }



