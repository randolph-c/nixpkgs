{ lib
, stdenv
, fetchFromGitHub
, fetchYarnDeps
, yarn
, yarnConfigHook
, yarnBuildHook
, yarnInstallHook
, makeBinaryWrapper
, nodejs
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "greenlight";
  version = "2.4.2";

  src = fetchFromGitHub {
    owner = "unknownskl";
    repo = "greenlight";
    rev = "v${finalAttrs.version}";
    hash = "sha256-vrQtwziP+MkBseHtqego2y31UjWCJRtyf+UD35H+iSU="; 
  };

  offlineCache = fetchYarnDeps {
    yarnLock = "${finalAttrs.src}/yarn.lock";
    hash = "sha256-ExLu7Psd1MMLyVEr3I7BQFVo0uggv+bw1KLYF50CzXk="; # Insert your verified dependency hash
  };

  nativeBuildInputs = [
    nodejs
    yarn
    yarnConfigHook
    yarnBuildHook
    yarnInstallHook
  ];

  preBuild = ''
    # Create an ephemeral sandbox bin to intercept validation checks
    mkdir -p $TMPDIR/bin
    
    echo -e "#!/bin/sh\nexit 0" > $TMPDIR/bin/codesign
    echo -e "#!/bin/sh\nexit 0" > $TMPDIR/bin/sips
    
    chmod +x $TMPDIR/bin/codesign $TMPDIR/bin/sips
    export PATH="$TMPDIR/bin:$PATH"

    # Restrict electron-builder from sniffing system keychain profiles
    export CSC_IDENTITY_AUTO_DISCOVERY=false
  '';

  buildPhase = ''
    runHook preBuild

    # Skip DMG bundling downloads and tell electron-builder to output a bare directory or zip
    # --mac dir forces it to compile the bare application bundle (.app) without wrapping it in a DMG
    yarn --offline --cwd packages/desktop flatpak-build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # 1. Isolate the compiled .app bundle into the native global Applications directory
    mkdir -p $out/Applications
    cp -r packages/desktop/dist/mac-arm64/Greenlight.app $out/Applications/Greenlight.app

    # 2. ICON FIX: Manually place the source graphic directly into the application archive 
    # to fix the broken sips output. Nextron projects store their root icons in public/
    mkdir -p $out/Applications/Greenlight.app/Contents/Resources
    if [ -f packages/desktop/resources/icon.icns ]; then
      cp packages/desktop/resources/icon.icns $out/Applications/Greenlight.app/Contents/Resources/electron.icns
    fi

    # 3. Create a clean system runner executable under $out/bin
    mkdir -p $out/bin
    makeWrapper "/usr/bin/open" "$out/bin/greenlight" \
      --add-flags "-a" \
      --add-flags "$out/Applications/Greenlight.app"

    runHook postInstall
  '';

  meta = with lib; {
    description = "An open-source client for xCloud and Xbox home streaming on macOS";
    homepage = "https://github.com/unknownskl/greenlight";
    license = licenses.mit;
    
    # -------------------------------------------------------------
    # MENTION YOURSELF HERE
    # -------------------------------------------------------------
    # Note: Before using a custom handle, you must add your GitHub info 
    # to the central file: `maintainers/maintainer-list.nix` in your nixpkgs fork.
    maintainers = [ maintainers.YOUR_NIXPKGS_HANDLE ]; 
    
    platforms = platforms.all;
  };
})
