BeforeAll {
  . $PSScriptRoot/DocFxHelper.ps1  
}

Describe 'Get-NormalizedTocItem href only' {
  Context 'Given href is folder, it returns folder and guesses filename from foldername' {
    BeforeAll {
      $normalized = Get-NormalizedTocItem -Href "Foo/"
    }
    It "RelativePath should be empty" {
      $normalized.relativePath | Should -Be ""
    }  
    It "Foldername should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "Filename should be Foo.md" {
      $normalized.filename | Should -Be "Foo.md"
    }
  }

  Context 'Given href is folder/, it returns folder and guesses filename from foldername' {
    BeforeAll {
      $normalized = Get-NormalizedTocItem -Href "Foo/"
    }
    It "RelativePath should be empty" {
      $normalized.filename | Should -Be "Foo.md"
    }
    It "foldername should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }  
    It "filename should be Foo.md" {
      $normalized.filename | Should -Be "Foo.md"
    }
  }


  Context 'Given href is folder/toc.yml, it returns folder and guesses filename from foldername' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Href "Foo/"
    }
    It "relativePath Should be empty" {
      $normalized.relativePath | Should -Be ""
    }
    It "foldername Should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "filename Should be Foo.md" {
      $normalized.filename | Should -Be "Foo.md"
    }
  }


  Context 'Given href is folder/filename.md, it returns folder and filename' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Href "Foo/Bar.md"
    }
    It "relativePath Should be empty" {
      $normalized.relativePath | Should -Be ""
    }
    It "foldername Should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "filename Should be Bar.md" {
      $normalized.filename | Should -Be "Bar.md"
    }
  }

  Context 'Given href is sub/folder/filename.md, it returns sub, folder and filename' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Href "Snafu/Foo/Bar.md"
    }
    It "relativePath Should be Snafu" {
      $normalized.relativePath | Should -Be "Snafu"
    }
    It "foldername Should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "filename Should be Bar.md" {
      $normalized.filename | Should -Be "Bar.md"
    }
  }


  Context 'Given href is ../sub/folder/filename.md, it returns relative sub, folder and filename' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Href "../Snafu/Foo/Bar.md"
    }
    It "relativePath Should be ../Snafu" {
      $normalized.relativePath | Should -Be "../Snafu"
    }
    It "foldername Should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "filename Should be Bar.md" {
      $normalized.filename | Should -Be "Bar.md"
    }
  }
}

Describe 'Get-NormalizedTocItem homepage only' {

  Context 'Given homepage is filename.md, it returns folder and homepage' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Homepage "Bar.md"
    }
    It "relativePath Should be empty" {
      $normalized.relativePath | Should -Be ""
    }
    It "foldername Should be Bar" {
      $normalized.foldername | Should -Be "Bar"
    }
    It "filename Should be Bar.md" {
      $normalized.filename | Should -Be "Bar.md"
    }
  }

  Context 'Given homepage is foo/filename.md, it returns folder and homepage' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Homepage "Foo/Bar.md"
    }
    It "relativePath Should be empty" {
      $normalized.relativePath | Should -Be ""
    }
    It "foldername Should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "filename Should be Bar.md" {
      $normalized.filename | Should -Be "Bar.md"
    }
  }

  Context 'Given homepage is snafu/foo/filename.md, it returns relative, folder and homepage' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Homepage "Snafu/Foo/Bar.md"
    }
    It "relativePath Should be Snafu" {
      $normalized.relativePath | Should -Be "Snafu"
    }
    It "foldername Should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "filename Should be Bar.md" {
      $normalized.filename | Should -Be "Bar.md"
    } 
  }

  Context 'Given homepage is ../snafu/foo/filename.md, it returns relative, folder and homepage' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Homepage "../Snafu/Foo/Bar.md"
    }
    It "relativePath Should be ../Snafu" {
      $normalized.relativePath | Should -Be "../Snafu"
    }
    It "foldername Should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "filename Should be Bar.md" {
      $normalized.filename | Should -Be "Bar.md"
    }
  }
}



Describe 'Get-NormalizedTocItem href and homepage are specified' {

  Context 'Given href is folder and homepage, it returns folder and homepage' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Href "Foo" -Homepage "Bar.md"
    }
    It "relativePath Should be empty" {
      $normalized.relativePath | Should -Be ""
    }
    It "foldername Should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "filename Should be Bar.md" {
      $normalized.filename | Should -Be "Bar.md"
    }
  }

  Context 'Given href is folder/ and homepage, it returns folder and homepage' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Href "Foo/" -Homepage "Bar.md"
    }
    It "relativePath Should be empty" {
      $normalized.relativePath | Should -Be ""
    }
    It "foldername Should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "filename Should be Bar.md" {
      $normalized.filename | Should -Be "Bar.md"
    }
  }

  Context 'Given href is folder/toc.yml and homepage, it returns folder and homepage' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Href "Foo/toc.yml" -Homepage "Bar.md"
    }
    It "relativePath Should be empty" {
      $normalized.relativePath | Should -Be ""
    }
    It "foldername Should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "filename Should be Bar.md" {
      $normalized.filename | Should -Be "Bar.md"
    }
  }

  Context 'Given href is sub/folder/toc.yml and homepage, it returns folder and homepage' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Href "Snafu/Foo/toc.yml" -Homepage "Bar.md"
    }
    It "relativePath Should be Snafu" {
      $normalized.relativePath | Should -Be "Snafu"
    }
    It "foldername Should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "filename Should be Bar.md" {
      $normalized.filename | Should -Be "Bar.md"
    }
  }

  Context 'Given href is relative ../sub/folder/toc.yml and homepage, it returns folder and homepage' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Href "../Snafu/Foo/toc.yml" -Homepage "Bar.md"
    }
    It "relativePath Should be ../Snafu" {
      $normalized.relativePath | Should -Be "../Snafu"
    }
    It "Foldername Should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "Filename Should be Bar.md" {
      $normalized.filename | Should -Be "Bar.md"
    }
  }

  Context 'Given href is relative ../sub/folder/toc.yml and homepage is ../anothersub/anotherFolder/homepage, it returns href sub, href folder and homepage' {
    BeforeAll{
      $normalized = Get-NormalizedTocItem -Href "../Snafu/Foo/toc.yml" -Homepage "../AnotherSnafu/AnotherFoo/Bar.md"
    }
    It "RelativePath Should be ../Snafu" {
      $normalized.relativePath | Should -Be "../Snafu"
    }
    It "Foldername Should be Foo" {
      $normalized.foldername | Should -Be "Foo"
    }
    It "Filename Should be Bar.md" {
      $normalized.filename | Should -Be "Bar.md"
    }

  }
}