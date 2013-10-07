<#  
    Authored by Emmanuel Acheampong 
    Based on articles such as : 
        http://visualstudiomagazine.com/articles/2011/07/28/wcoss_coded-builds.aspx
        http://ayende.com/blog/4156/on-psake
        http://codecampserver.codeplex.com/SourceControl/changeset/view/4755c1386bff#default.ps1
        https://gist.github.com/toddb/1133511
        https://gist.github.com/toddb/1133511/raw/45404dbfa3c115ced13c44aa7a91b41e87177f34/build-tasks.ps1
#>

	properties { 
	  $project = "PerfTap"
	  
	  $environment = ""   # handed in commmand line
	  $verbosity = "n"    # verbosity levels: q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic].
	  $revision = "0"     # handed in commmand line
	  $main = "1.0"       # will read the first 2 values from a version file.
      $build_number = "0" # come from team city
	  $today = Get-Date
      $version = ''       # Injected by script
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
	  
      $7z_exe = "$tools_dir\7z\7z.exe" 
	  $sln_file = "$src_dir\$project.sln"
	}

    task Build -depends Compile, Test
    task Generate_Configs
    task Package -depends Default, Zip
    task Deploy -depends Extract

    task Default -depends Clean, Assembly_Info, Compile
    task CI_Build -depends default, Test, Inspection, Package

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

	task Test  {
		assert(Test-Path($test_runner_path)) "xUnit must be available."
		assert(Test-Path($test_path)) "PerfTap.Test Path must be available."
        $testassemblies = get-childitem $release_dir -recurse -include *tests*.dll
        exec { 
            & $test_runner_path $testassemblies /Teamcity /html $test_runner_opts
        }
    }

	task IntegrationTest  {
		assert(Test-Path($test_runner_path)) "xUnit must be available."
		assert(Test-Path($test_path)) "PerfTap.Test Path must be available."
        $testassemblies = get-childitem $release_dir -recurse -include *tests*.dll
        exec { 
            & $test_runner_path $testassemblies /Teamcity /html $test_runner_opts
        }
    }
       
    task Extract -Description "Unzips the packing zip archive" {
		Extract-Zip "$release_dir\$project-v$version.zip" $package_dir
	}
	
    task Zip -Description "Unzips the packing zip archive" {
    # Write-Host $version
		Create-Zip "$package_dir\$project-v$version.zip" $release_dir
	}

    task Inspection {
        run_fxcop
    }
    
    task Assembly_Info {
        $version = Generate-VersionNumber        
		Update-AssemblyInfoFiles $version $assemblyinfo_excludes
	}

    #------------------------------------------------
    # Helper Functions, will be moved out to includes
    #------------------------------------------------

    function Writeable-AssemblyInfoFile($filename)
    {
	    sp $filename IsReadOnly $false
    }

    function ReadOnly-AssemblyInfoFile($filename)
    {
	    sp $filename IsReadOnly $true
    }

    function run_fxcop
    {
        & .\tools\FxCop\FxCopCmd.exe /out:$output_dir\FxCopy.xml  /file:$test_dir\$project**.dll /quiet /d:$test_dir /c /summary | out-file $output_dir\fxcop.log
    }

    function Generate-VersionNumber 
    {
        if ($build_number -eq 0) #Check for build number - only present on build agents
        {
            $build_number = ( ($today.year - 2000) * 1000 + $today.DayOfYear )
        } 
        return $main + "." + $build_number + "." + $revision
        
    }

    function Update-AssemblyInfoFiles ([string] $version, [System.Array] $excludes = $null, $make_writeable = $false) 
    {

        #-------------------------------------------------------------------------------
        # Update version numbers of AssemblyInfo.cs
        # adapted from: http://www.luisrocha.net/2009/11/setting-assembly-version-with-windows.html
        # Version information for an assembly consists of the following four values:
        #
        #      Major Version
        #      Minor Version 
        #      Build Number
        #      Revision
        #
        #-------------------------------------------------------------------------------

        Write-Host $version
	    if ($version -notmatch "[0-9]+(\.([0-9]+|\*)){1,3}") {
		    Write-Error "Version number incorrect format: $version"
	    }
	
	    $versionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
	    $versionAssembly = 'AssemblyVersion("' + $version + '")';
	    $versionFilePattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
	    $versionAssemblyFile = 'AssemblyFileVersion("' + $version + '")';

        write-host "Scanning for AssemblyInfo.cs"
        
        Get-ChildItem $src_dir -r -filter AssemblyInfo.cs | % {
        	$filename = $_.fullname
		    $update_assembly_and_file = $true
            
            # set an exclude flag where only AssemblyFileVersion is set
		    if ($excludes -ne $null)
			    { $excludes | % { if ($filename -match $_) { $update_assembly_and_file = $false	} } }
	
		    if ($make_writable) { Writeable-AssemblyInfoFile($filename) }

		    $tmp = ($file + ".tmp")
		    if (test-path ($tmp)) { remove-item $tmp }

		    if ($update_assembly_and_file) {
			    (get-content $filename) | % {$_ -replace $versionFilePattern, $versionAssemblyFile } | % {$_ -replace $versionPattern, $versionAssembly }  > $tmp
			    write-host Updating file AssemblyInfo and AssemblyFileInfo: $filename --> $versionAssembly / $versionAssemblyFile
		    } else {
			    (get-content $filename) | % {$_ -replace $versionFilePattern, $versionAssemblyFile } > $tmp
			    write-host Updating file AssemblyInfo only: $filename --> $versionAssemblyFile
		    }

		    if (test-path ($filename)) { remove-item $filename }
		    move-item $tmp $filename -force	

		    if ($make_writable) { ReadOnly-AssemblyInfoFile($filename) }
                write-host "resulting in $filename"		
                
                Write-Host $version
	    }
    }

    function Create-Zip($file, $dir, $7z)
    {
        if ($7z -eq $null) { $7z = $7z_exe }
	    if (Test-Path -path $file) { remove-item $file }
	    Create-Directory $dir
	    exec { & $7z a -tzip $file $dir\* } 
    }

    function Extract-Zip($file, $extract_dir, $7z)
    {
      if ($7z -eq $null) { $7z = $7z_exe }
      Delete-Directory $extract_dir
      Create-Directory $extract_dir
      exec { & $7z x $file -aoa "-o$extract_dir"} 
    }
    
    function CopyTo-Directory($files, $dir){
	    Create-Directory $dir
	    cp $files $dir -recurse -container
    }

    function Delete-Directory($dir){
	    if (Test-Path -path $dir) { rmdir $dir -recurse -force }
    }

    function Create-Directory($dir){
	    if (!(Test-Path -path $dir)) { new-item $dir -force -type directory}
    }

