param(
  [string]$Repo = "fubaoiscat/xhs-image-note-extractor",
  [string]$Ref = "latest",
  [string]$Target = "$HOME\.claude\skills\xhs-image-note-extractor",
  [switch]$SkipTesseract
)

$ErrorActionPreference = "Stop"

function Write-Info($Message) {
  Write-Host "[xhs-installer] $Message"
}

function Download-Archive {
  param(
    [string]$RepoName,
    [string]$RefName,
    [string]$Output
  )

  $candidates = @(
    "https://github.com/$RepoName/archive/refs/heads/$RefName.zip",
    "https://github.com/$RepoName/archive/refs/tags/$RefName.zip",
    "https://github.com/$RepoName/archive/$RefName.zip"
  )

  foreach ($url in $candidates) {
    try {
      Invoke-WebRequest -Uri $url -OutFile $Output
      return
    } catch {
      continue
    }
  }

  throw "Unable to download $RepoName@$RefName"
}

function Resolve-Ref {
  param(
    [string]$RepoName,
    [string]$RefName
  )

  if ($RefName -ne "latest") {
    return $RefName
  }

  $api = "https://api.github.com/repos/$RepoName/releases/latest"
  Write-Info "Resolving latest release tag from $RepoName..."
  try {
    $release = Invoke-RestMethod -Uri $api
  } catch {
    throw "Could not resolve latest release tag for $RepoName. Pass -Ref <tag|branch|sha>."
  }

  if (-not $release.tag_name) {
    throw "No release tag found for $RepoName. Please publish a release or pass -Ref."
  }

  Write-Info "Using release tag: $($release.tag_name)"
  return $release.tag_name
}

function Ensure-Tesseract {
  if (Get-Command tesseract -ErrorAction SilentlyContinue) {
    $version = (& tesseract --version | Select-Object -First 1)
    Write-Info "tesseract already installed: $version"
    return
  }

  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Info "Installing tesseract via winget..."
    winget install --exact --id UB-Mannheim.TesseractOCR --accept-source-agreements --accept-package-agreements
    return
  }
  if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Info "Installing tesseract via choco..."
    choco install -y tesseract
    return
  }
  if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Info "Installing tesseract via scoop..."
    scoop install tesseract
    return
  }

  throw "No supported package manager found (winget/choco/scoop). Install tesseract manually."
}

function Verify-Languages {
  $langs = & tesseract --list-langs 2>$null
  if ($langs -notcontains "chi_sim") {
    throw "Language data missing: chi_sim"
  }
  if ($langs -notcontains "eng") {
    throw "Language data missing: eng"
  }
}

$tmp = Join-Path $env:TEMP ("xhs-skill-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
  $Ref = Resolve-Ref -RepoName $Repo -RefName $Ref
  $archive = Join-Path $tmp "skill.zip"
  Write-Info "Downloading $Repo@$Ref..."
  Download-Archive -RepoName $Repo -RefName $Ref -Output $archive

  Expand-Archive -Path $archive -DestinationPath $tmp
  $src = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
  if (-not $src) {
    throw "Archive extraction failed."
  }

  $parent = Split-Path -Parent $Target
  if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  if (Test-Path $Target) {
    Remove-Item -Recurse -Force $Target
  }
  Move-Item -Path $src.FullName -Destination $Target
  Write-Info "Skill installed to: $Target"

  if (-not $SkipTesseract) {
    Ensure-Tesseract
    Verify-Languages
  }

  Write-Info "Done. Quick check:"
  Write-Host "  node `"$Target\scripts\parse-xhs-page.mjs`" --help"
  Write-Host "  node `"$Target\scripts\ocr-image.mjs`" C:\path\to\image.jpg"
} finally {
  if (Test-Path $tmp) {
    Remove-Item -Recurse -Force $tmp
  }
}
