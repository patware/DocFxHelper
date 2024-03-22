BeforeAll {
  . $PSScriptRoot/DocFxHelper.ps1
}

Describe 'Resolve-TocItem' {
  Context "Scenario 01 - [Bar/] [Foo.md] : Given toc.yml at root, href set to [Bar/] and [Bar/toc.yml] exists, and homepage is [Foo.md] it returns [Bar/toc.yml] and [Foo.md]" {
    BeforeEach {
      Mock -CommandName Push-Location -MockWith {}
      Mock -CommandName Pop-Location -MockWith {}

      Mock -CommandName Test-Path  -MockWith {$true}                                                                              -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/")}
      Mock -CommandName Test-Path  -MockWith {$true}                                                                              -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar\toc.yml")}
      Mock -CommandName Get-Item   -MockWith {@{
        Name="toc.yml"
        FullName=((Join-Path (Get-Location).Path -childPath "Bar/toc.yml"))
        Directory=@{Name="Bar";FullName=((Join-Path (Get-Location).Path -childPath "Bar"))}
      }}                                                                                                                          -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/toc.yml")}      
      Mock -CommandName Test-Path  -MockWith {$true}                                                                              -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}
      Mock -CommandName Get-Item   -MockWith {@{Name="Foo.md";   FullName=((Join-Path (Get-Location).Path -childPath "Foo.md"))}} -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}

      Mock -CommandName Resolve-Path -MockWith {"Bar\toc.yml"}                                                                    -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar\toc.yml")}
      Mock -CommandName Resolve-Path -MockWith {"Bar"}                                                                            -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar")}
      Mock -CommandName Resolve-Path -MockWith {"Foo.md"}                                                                         -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}

      $tocPath = (Join-Path (Get-Location).Path -childPath "toc.yml")
      $tocUri = [Uri]::new($baseUri, "/")
      $tocItem = @{href="Bar/";homepage="Foo.md"}

    }  

    It 'toc_yml_Path should be Bar\toc.yml' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.toc_yml_Path | Should -Be "Bar\toc.yml"
      
      Should -InvokeVerifiable
      
    }

    It 'file_md_SubFolder_Path should be Bar' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.file_md_SubFolder_Path | Should -Be "Bar"
      
      Should -InvokeVerifiable
    }


    It 'file_md_Path should be Foo.md' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem

      $resolved.file_md_Path | Should -Be "Foo.md"
      
      Should -InvokeVerifiable
      
    }


    AfterEach {
      
    } 
  }

  Context "Scenario 02 - [Bar/] [Bar/Foo.md] : Given toc.yml at root, href set to [Bar/] and [Bar/toc.yml] exists, and homepage is [Bar/Foo.md] it returns [Bar/toc.yml] and [Bar/Foo.md]" {
    BeforeEach {
      Mock -CommandName Push-Location -MockWith {}
      Mock -CommandName Pop-Location -MockWith {}

      Mock -CommandName Test-Path  -MockWith {$true}                                                                                  -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/")}
      Mock -CommandName Test-Path  -MockWith {$true}                                                                                  -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar\toc.yml")}
      Mock -CommandName Get-Item   -MockWith {@{
        Name="toc.yml"
        FullName=((Join-Path (Get-Location).Path -childPath "Bar/toc.yml"))
        Directory=@{Name="Bar";FullName=((Join-Path (Get-Location).Path -childPath "Bar"))}
      }}                                                                                                                              -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/toc.yml")}
      Mock -CommandName Test-Path  -MockWith {$true}                                                                                  -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/Foo.md")}
      Mock -CommandName Get-Item   -MockWith {@{Name="Foo.md";   FullName=((Join-Path (Get-Location).Path -childPath "Bar/Foo.md"))}} -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/Foo.md")}

      Mock -CommandName Resolve-Path -MockWith {"Bar\toc.yml"}                                                                        -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar\toc.yml")}
      Mock -CommandName Resolve-Path -MockWith {"Bar"}                                                                                -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar")}
      Mock -CommandName Resolve-Path -MockWith {"Bar\Foo.md"}                                                                         -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/Foo.md")}

      $tocPath = (Join-Path (Get-Location).Path -childPath "toc.yml")
      $tocUri = [Uri]::new($baseUri, "/")
      $tocItem = @{href="Bar/";homepage="Bar/Foo.md"}
    }  

    It 'toc_yml_Path should be Bar\toc.yml' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.toc_yml_Path | Should -Be "Bar\toc.yml"
      
      Should -InvokeVerifiable
      
    }

    It 'file_md_SubFolder_Path should be Bar' {
     
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.file_md_SubFolder_Path | Should -Be "Bar"
     
      Should -InvokeVerifiable
    }


    It 'file_md_Path should be Bar\Foo.md' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem

      $resolved.file_md_Path | Should -Be "Bar\Foo.md"
      
      Should -InvokeVerifiable
      
    }


    AfterEach {
      
    } 
  }

  Context "Scenario 03 - [Bar/toc.yml] [Foo.md] : Given toc.yml at root, href set to [Bar/toc.yml] and [Bar/toc.yml] exists, and homepage is [Foo.md] it returns [Bar/toc.yml] and [Foo.md]" {
    BeforeEach {
      Mock -CommandName Push-Location -MockWith {}
      Mock -CommandName Pop-Location -MockWith {}

      Mock -CommandName Get-Item   -MockWith {@{
        Name="toc.yml"
        FullName=((Join-Path (Get-Location).Path -childPath "Bar/toc.yml"))
        Directory=@{Name="Bar";FullName=((Join-Path (Get-Location).Path -childPath "Bar"))}
      }}                                                                                                                          -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/toc.yml")}
      Mock -CommandName Test-Path  -MockWith {$true}                                                                              -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}
      Mock -CommandName Get-Item   -MockWith {@{Name="Foo.md";   FullName=((Join-Path (Get-Location).Path -childPath "Foo.md"))}} -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}

      Mock -CommandName Resolve-Path -MockWith {"Bar\toc.yml"}                                                                    -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar\toc.yml")}
      Mock -CommandName Resolve-Path -MockWith {"Bar"}                                                                            -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar")}
      Mock -CommandName Resolve-Path -MockWith {"Foo.md"}                                                                         -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}

      $tocPath = (Join-Path (Get-Location).Path -childPath "toc.yml")
      $tocUri = [Uri]::new($baseUri, "/")
      $tocItem = @{href="Bar/toc.yml";homepage="Foo.md"}
    }  

    It 'toc_yml_Path should be Bar\toc.yml' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.toc_yml_Path | Should -Be "Bar\toc.yml"
      
      Should -InvokeVerifiable
    }

    It 'file_md_SubFolder_Path should be Bar' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.file_md_SubFolder_Path | Should -Be "Bar"
      
      Should -InvokeVerifiable
    }


    It 'file_md_Path should be Foo.md' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem

      $resolved.file_md_Path | Should -Be "Foo.md"
      
      Should -InvokeVerifiable
    }


    AfterEach {
      
    } 
  }


  Context "Scenario 04 - [Bar/toc.yml] [Bar/Foo.md] : Given toc.yml at root, href set to [Bar/toc.yml] and [Bar/toc.yml] exists, and homepage is [Bar/Foo.md] it returns [Bar/toc.yml] and [Bar/Foo.md]" {
    BeforeEach {
      Mock -CommandName Push-Location -MockWith {}
      Mock -CommandName Pop-Location -MockWith {}

      Mock -CommandName Get-Item   -MockWith {@{
        Name="toc.yml"
        FullName=((Join-Path (Get-Location).Path -childPath "Bar/toc.yml"))
        Directory=@{Name="Bar";FullName=((Join-Path (Get-Location).Path -childPath "Bar"))}
      }}                                                                                                                              -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/toc.yml")}
      Mock -CommandName Test-Path  -MockWith {$true}                                                                                  -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/Foo.md")}
      Mock -CommandName Get-Item   -MockWith {@{Name="Foo.md";   FullName=((Join-Path (Get-Location).Path -childPath "Bar/Foo.md"))}} -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/Foo.md")}

      Mock -CommandName Resolve-Path -MockWith {"Bar\toc.yml"}                                                                        -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar\toc.yml")}
      Mock -CommandName Resolve-Path -MockWith {"Bar"}                                                                                -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar")}
      Mock -CommandName Resolve-Path -MockWith {"Bar\Foo.md"}                                                                         -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar\Foo.md")}

      $tocPath = (Join-Path (Get-Location).Path -childPath "toc.yml")
      $tocUri = [Uri]::new($baseUri, "/")
      $tocItem = @{href="Bar/toc.yml";homepage="Bar/Foo.md"}
    }  

    It 'toc_yml_Path should be Bar\toc.yml' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.toc_yml_Path | Should -Be "Bar\toc.yml"
      
      Should -InvokeVerifiable
    }

    It 'file_md_SubFolder_Path should be Bar' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.file_md_SubFolder_Path | Should -Be "Bar"

      Should -InvokeVerifiable
    }


    It 'file_md_Path should be Bar\Foo.md' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem

      $resolved.file_md_Path | Should -Be "Bar\Foo.md"
      
      Should -InvokeVerifiable
    }


    AfterEach {
      
    } 
  }



  Context "Scenario 05 - [Foo.md] Foo/ does not exist: Given toc.yml at root, href set to [Foo.md], subFolder Foo does not exist, it returns toc null, folder null, md_File [Foo.md]" {
    BeforeEach {
      Mock -CommandName Push-Location -MockWith {}
      Mock -CommandName Pop-Location -MockWith {}

      Mock -CommandName Test-Path  -MockWith {$true}                       -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}
      Mock -CommandName Get-Item   -MockWith {@{
        Name="Foo.md"
        FullName=((Join-Path (Get-Location).Path -childPath "Foo.md"))
        PSIsContainer = $false
      }}                                                                    -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}
      Mock -CommandName Test-Path  -MockWith {$false}                       -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo")}

      Mock -CommandName Resolve-Path -MockWith {"Foo.md"}                   -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}

      $tocPath = (Join-Path (Get-Location).Path -childPath "toc.yml")
      $tocUri = [Uri]::new($baseUri, "/")
      $tocItem = @{href="Foo.md"}
    }  

    It 'toc_yml_Path should be null' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.toc_yml_Path | Should -Be $null
      
      Should -InvokeVerifiable
    }

    It 'file_md_SubFolder_Path should be null' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.file_md_SubFolder_Path | Should -Be $null

      Should -InvokeVerifiable
    }


    It 'file_md_Path should be Foo.md' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem

      $resolved.file_md_Path | Should -Be "Foo.md"
      
      Should -InvokeVerifiable
    }


    AfterEach {
      
    } 
  }

  Context "Scenario 06 - [Foo.md] Foo/ exists, but not Foo/toc.yml: Given toc.yml at root, href set to [Foo.md], subFolder Foo/ exists but not Foo/toc.yml, it returns toc null, folder [Foo], md_File [Foo.md]" {
    BeforeEach {
      Mock -CommandName Push-Location -MockWith {}
      Mock -CommandName Pop-Location -MockWith {}

      Mock -CommandName Test-Path  -MockWith {$true}                      -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}
      Mock -CommandName Get-Item   -MockWith {@{
        Name="Foo.md"
        FullName=((Join-Path (Get-Location).Path -childPath "Foo.md"))
        PSIsContainer = $false
      }}                                                                  -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}
      Mock -CommandName Test-Path  -MockWith {$true}                      -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo")}
      Mock -CommandName Test-Path  -MockWith {$false}                     -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo/toc.yml")}
      Mock -CommandName Get-Item   -MockWith {@{
        Name="Foo"
        FullName=((Join-Path (Get-Location).Path -childPath "Foo"))
      }}                                                                  -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo")}

      Mock -CommandName Resolve-Path -MockWith {"Foo"}                    -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo")}
      Mock -CommandName Resolve-Path -MockWith {"Foo.md"}                 -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}

      $tocPath = (Join-Path (Get-Location).Path -childPath "toc.yml")
      $tocUri = [Uri]::new($baseUri, "/")
      $tocItem = @{href="Foo.md"}
    }  

    It 'toc_yml_Path should be null' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.toc_yml_Path | Should -Be $null
      
      Should -InvokeVerifiable
    }

    It 'file_md_SubFolder_Path should be Foo' {
     
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.file_md_SubFolder_Path | Should -Be "Foo"

      Should -InvokeVerifiable
    }


    It 'file_md_Path should be Foo.md' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem

      $resolved.file_md_Path | Should -Be "Foo.md"
      
      Should -InvokeVerifiable
    }


    AfterEach {
      
    } 
  }

  Context "Scenario 07 - [Foo.md] Foo/toc.yml exists: Given toc.yml at root, href set to [Foo.md], subFolder Foo/toc.yml exists, it returns toc [Foo/toc.yml], folder [Foo], md_File [Foo.md]" {
    BeforeEach {
      Mock -CommandName Push-Location -MockWith {}
      Mock -CommandName Pop-Location -MockWith {}

      Mock -CommandName Test-Path  -MockWith {$true}                      -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}
      Mock -CommandName Get-Item   -MockWith {@{
        Name="Foo.md"
        FullName=((Join-Path (Get-Location).Path -childPath "Foo.md"))
        PSIsContainer = $false
      }}                                                                  -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}
      Mock -CommandName Test-Path  -MockWith {$true}                      -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo")}
      Mock -CommandName Test-Path  -MockWith {$true}                      -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo/toc.yml")}
      Mock -CommandName Get-Item   -MockWith {@{
        Name="Foo"
        FullName=((Join-Path (Get-Location).Path -childPath "Foo"))
      }}                                                                  -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo")}
      Mock -CommandName Get-Item   -MockWith {@{
        Name="toc.yml"
        FullName=((Join-Path (Get-Location).Path -childPath "Foo/toc.yml"))
        Directory=@{Name="Foo";FullName=((Join-Path (Get-Location).Path -childPath "Foo"))}
      }}                                                                  -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo/toc.yml")}
      
      Mock -CommandName Resolve-Path -MockWith {"Foo\toc.yml"}            -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo\toc.yml")}
      Mock -CommandName Resolve-Path -MockWith {"Foo"}                    -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo")}
      Mock -CommandName Resolve-Path -MockWith {"Foo.md"}                 -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}

      $tocPath = (Join-Path (Get-Location).Path -childPath "toc.yml")
      $tocUri = [Uri]::new($baseUri, "/")
      $tocItem = @{href="Foo.md"}
    }  

    It 'toc_yml_Path should be Foo\toc.yml' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.toc_yml_Path | Should -Be "Foo\toc.yml"
      
      Should -InvokeVerifiable
    }

    It 'file_md_SubFolder_Path should be Foo' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.file_md_SubFolder_Path | Should -Be "Foo"

      Should -InvokeVerifiable
    }


    It 'file_md_Path should be Foo.md' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem

      $resolved.file_md_Path | Should -Be "Foo.md"
      
      Should -InvokeVerifiable
    }


    AfterEach {
      
    } 
  }

  Context "Scenario 08 - [Bar/] Bar.md does not exist: Given toc.yml at root, href set to [Bar/], subFolder Bar/toc.yml exists but Bar.md not, it returns toc [Bar/toc.yml], folder [Bar], md_File null" {
    BeforeEach {
      Mock -CommandName Push-Location -MockWith {}
      Mock -CommandName Pop-Location -MockWith {}

      Mock -CommandName Test-Path  -MockWith {$true}                       -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/")}
      Mock -CommandName Test-Path  -MockWith {$true}                       -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/toc.yml")}
      Mock -CommandName Get-Item   -MockWith {@{
        Name="toc.yml"
        FullName=((Join-Path (Get-Location).Path -childPath "Bar/toc.yml"))
        Directory=@{Name="Bar";FullName=((Join-Path (Get-Location).Path -childPath "Bar"))}
        PSIsContainer = $false
      }}                                                                    -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar/toc.yml")}
      
      Mock -CommandName Test-Path  -MockWith {$false}                       -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar.md")}

      Mock -CommandName Resolve-Path -MockWith {"Bar\toc.yml"}              -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar\toc.yml")}
      Mock -CommandName Resolve-Path -MockWith {"Bar"}                      -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Bar")}

      $tocPath = (Join-Path (Get-Location).Path -childPath "toc.yml")
      $tocUri = [Uri]::new($baseUri, "/")
      $tocItem = @{href="Bar/"}
    }  

    It 'toc_yml_Path should be Bar\toc.yml' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.toc_yml_Path | Should -Be "Bar\toc.yml"
      
      Should -InvokeVerifiable
    }

    It 'file_md_SubFolder_Path should be Bar' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.file_md_SubFolder_Path | Should -Be "Bar"

      Should -InvokeVerifiable
    }


    It 'file_md_Path should be null' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem

      $resolved.file_md_Path | Should -Be $null
      
      Should -InvokeVerifiable
    }


    AfterEach {
      
    } 
  }


  Context "Scenario 09 - [Foo/] Foo.md exists: Given toc.yml at root, href set to [Foo/], subFolder Foo/toc.yml exists and Foo.md not, it returns toc [Foo/toc.yml], folder [Foo], md_File [Foo.md]" {
    BeforeEach {
      Mock -CommandName Push-Location -MockWith {}
      Mock -CommandName Pop-Location -MockWith {}

      Mock -CommandName Test-Path  -MockWith {$true}                        -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo/")}
      Mock -CommandName Test-Path  -MockWith {$true}                        -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo\toc.yml")}
      Mock -CommandName Get-Item   -MockWith {@{
        Name="toc.yml"
        FullName=((Join-Path (Get-Location).Path -childPath "Foo\toc.yml"))
        Directory=@{Name="Foo";FullName=((Join-Path (Get-Location).Path -childPath "Foo"))}
        PSIsContainer = $false
      }}                                                                    -Verifiable -ParameterFilter { $Path -and $Path.replace("/","\") -eq (Join-Path (Get-Location).Path -childPath "Foo\toc.yml")}
      
      Mock -CommandName Test-Path  -MockWith {$true}                        -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}
      Mock -CommandName Get-Item   -MockWith {@{
        Name="Foo.md"
        FullName=((Join-Path (Get-Location).Path -childPath "Foo.md"))
        PSIsContainer = $false
      }}                                                                    -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}

      Mock -CommandName Resolve-Path -MockWith {"Foo\toc.yml"}              -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo\toc.yml")}
      Mock -CommandName Resolve-Path -MockWith {"Foo"}                      -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo")}
      Mock -CommandName Resolve-Path -MockWith {"Foo.md"}                   -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}

      $tocPath = (Join-Path (Get-Location).Path -childPath "toc.yml")
      $tocUri = [Uri]::new($baseUri, "/")
      $tocItem = @{href="Foo/"}
    }  

    It 'toc_yml_Path should be Foo\toc.yml' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.toc_yml_Path | Should -Be "Foo\toc.yml"
      
      Should -InvokeVerifiable
    }

    It 'file_md_SubFolder_Path should be Foo' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.file_md_SubFolder_Path | Should -Be "Foo"

      Should -InvokeVerifiable
    }


    It 'file_md_Path should be Foo.md' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem

      $resolved.file_md_Path | Should -Be "Foo.md"
      
      Should -InvokeVerifiable
    }


    AfterEach {
      
    } 
  }

  Context "Scenario 10 - [Foo/toc.yml]: Given toc.yml at root, href set to [Foo/toc.yml], subFolder Foo/toc.yml and Foo.md exists, it returns toc [Foo/toc.yml], folder [Foo], md_File [Foo.md]" {
    BeforeEach {
      Mock -CommandName Push-Location -MockWith {}
      Mock -CommandName Pop-Location -MockWith {}

      Mock -CommandName Test-Path  -MockWith {$true}                        -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo/toc.yml")}
      Mock -CommandName Get-Item   -MockWith {@{
        Name="toc.yml"
        FullName=((Join-Path (Get-Location).Path -childPath "Foo\toc.yml"))
        Directory=@{Name="Foo";FullName=((Join-Path (Get-Location).Path -childPath "Foo"))}
        PSIsContainer = $false
      }}                                                                    -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo\toc.yml")}
      Mock -CommandName Test-Path  -MockWith {$true}                        -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}
      Mock -CommandName Get-Item   -MockWith {@{
        Name="Foo.md"
        FullName=((Join-Path (Get-Location).Path -childPath "Foo.md"))
        PSIsContainer = $false
      }}                                                                    -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}

      Mock -CommandName Resolve-Path -MockWith {"Foo\toc.yml"}              -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo\toc.yml")}
      Mock -CommandName Resolve-Path -MockWith {"Foo"}                      -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo")}
      Mock -CommandName Resolve-Path -MockWith {"Foo.md"}                   -Verifiable -ParameterFilter { $Path -and $Path -eq (Join-Path (Get-Location).Path -childPath "Foo.md")}

      $tocPath = (Join-Path (Get-Location).Path -childPath "toc.yml")
      $tocUri = [Uri]::new($baseUri, "/")
      $tocItem = @{href="Foo/toc.yml"}
    }  

    It 'toc_yml_Path should be Foo\toc.yml' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.toc_yml_Path | Should -Be "Foo\toc.yml"
      
      Should -InvokeVerifiable
    }

    It 'file_md_SubFolder_Path should be Foo' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem
        
      $resolved.file_md_SubFolder_Path | Should -Be "Foo"

      Should -InvokeVerifiable
    }


    It 'file_md_Path should be Foo.md' {
      
      $resolved = Resolve-TocItem -TocYmlPath $tocPath -TocUri $tocUri -TocItem $tocItem

      $resolved.file_md_Path | Should -Be "Foo.md"
      
      Should -InvokeVerifiable
    }


    AfterEach {
      
    } 
  }
  
}