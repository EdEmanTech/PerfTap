<#  
    Authored by Emmanuel Acheampong 
    Based on articles such as : 
        http://visualstudiomagazine.com/articles/2011/07/28/wcoss_coded-builds.aspx
        http://ayende.com/blog/4156/on-psake
        https://gist.github.com/toddb/1133511
#>

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
	  $package_dir = "$output_dir\Packages"	  
	  
	  $test_runner_path = "$tools_dir\xunit.runners.1.9.2\tools\xunit.console.clr4.exe"
	  $test_runner_opts = "$output_dir\xunit.results.html"

  	  $test_dir = "$src_dir\$project.Tests\$configuration"
	  $test_path = "$release_dir\$project.Tests.dll"
	   
	  $sln_file = "$src_dir\$project.sln"
	}
#
 #   Include  .\teamcity.psm1
  #  TaskSetup {
   #     TeamCity-ReportBuildProgress "Running task $($script:context.Peek().currentTaskName)"
    #}

    task Clean { 
        remove-item -force -recurse $output_dir -ea SilentlyContinue | Out-Null
        remove-item -force -recurse $release_dir -ea SilentlyContinue | Out-Null
        remove-item -force -recurse $package_dir -ea SilentlyContinue | Out-Null
        exec { msbuild $sln_file /t:clean /verbosity:$verbosity }
    }

	
    task Init -depends Clean {
        new-item $release_dir -itemType directory | Out-Null 
        new-item $package_dir -itemType directory | Out-Null       
    }


	task Compile -depends Init {
		exec { msbuild $sln_file /t:rebuild "/p:Configuration=$config" "/p:Platform=$platform" /p:OutDir="$release_dir" }
	}


	task Test -depends Compile {
		assert(Test-Path($test_runner_path)) "xUnit must be available."
		assert(Test-Path($test_path)) "PerfTap.Test Path must be available."
        $testassemblies = get-childitem $release_dir -recurse -include *tests*.dll
        exec { 
            & $test_runner_path $testassemblies /Teamcity /html $test_runner_opts;
        }
    }

    task IntegrationTest -depends Test { 
        assert(Test-Path($test_runner_path)) "xUnit must be available."
        exec { cmd /C $test_runner_path $test_path /html $test_runner_opts }
    }

    Task Build -depends Compile
    Task Default -depends Build
    Task Package -depends Default, IntegrationTest


