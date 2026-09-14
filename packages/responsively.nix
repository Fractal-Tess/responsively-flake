{ lib
, stdenv
, source
, nodejs
, electron
, fetchYarnDeps
, yarnConfigHook
, makeWrapper
, makeDesktopItem
, copyDesktopItems
}:
let
  metadata = lib.importJSON "${source}/desktop-app/package.json";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "responsively";
  version = metadata.version;
  src = "${source}/desktop-app";

  buildOfflineCache = fetchYarnDeps {
    name = "responsively-build-deps";
    yarnLock = "${finalAttrs.src}/yarn.lock";
    hash = "sha256-lJ8P3NShg2g0jIHpVCghsaJmIuJU3laAV6grhY6KqLQ=";
  };
  runtimeOfflineCache = fetchYarnDeps {
    name = "responsively-runtime-deps";
    yarnLock = "${finalAttrs.src}/release/app/yarn.lock";
    hash = "sha256-yBxnShPLhjxDNc59g+a3YeHdS/4WWchMCj4ihtSlL/s=";
  };

  nativeBuildInputs = [ nodejs yarnConfigHook makeWrapper copyDesktopItems ];
  dontYarnInstallDeps = true;
  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  postPatch = ''
    # Shared Nix Electron keeps its own resources directory. Point the app at ours.
    substituteInPlace src/main/main.ts src/main/mcp/beacon.ts \
      --replace-fail 'process.resourcesPath' "'$out/lib/responsively/resources'"
    # Beacons must launch this app's wrapper, not a bare Electron executable.
    substituteInPlace src/main/mcp/beacon.ts \
      --replace-fail 'process.env.APPIMAGE ?? process.execPath' "'$out/bin/responsively'"
  '';

  configurePhase = ''
    runHook preConfigure
    yarnOfflineCache="$buildOfflineCache" yarnConfigHook
    (
      cd release/app
      yarnOfflineCache="$runtimeOfflineCache" yarnConfigHook
    )
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    yarn --offline tsx postinstall.ts
    yarn --offline run build:main
    yarn --offline run build:renderer
    yarn --offline run build:mcp
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/responsively/resources/app" "$out/bin"
    cp -r release/app/dist release/app/node_modules release/app/package.json \
      "$out/lib/responsively/resources/app/"
    mv "$out/lib/responsively/resources/app/dist/mcp" \
      "$out/lib/responsively/resources/mcp"
    cp -r assets "$out/lib/responsively/resources/assets"

    makeWrapper ${lib.getExe electron} "$out/bin/responsively" \
      --add-flags "$out/lib/responsively/resources/app" \
      --set ELECTRON_FORCE_IS_PACKAGED 1 \
      --inherit-argv0
    makeWrapper ${lib.getExe nodejs} "$out/bin/responsively-mcp" \
      --add-flags "$out/lib/responsively/resources/mcp/cli.js"
    # The upstream bridge finds the sibling application without a prior launch.
    ln -s "$out/bin/responsively" "$out/lib/responsively/responsively"

    install -Dm644 assets/icon.svg "$out/share/icons/hicolor/scalable/apps/responsively.svg"
    install -Dm644 LICENSE "$out/share/licenses/responsively/desktop-MIT"
    install -Dm644 "${source}/LICENSE" "$out/share/licenses/responsively/upstream-AGPL-3.0"
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "responsively";
      desktopName = "Responsively App";
      genericName = "Responsive web development browser";
      exec = "responsively %U";
      icon = "responsively";
      categories = [ "Development" "WebDevelopment" ];
      mimeTypes = [ "x-scheme-handler/responsively" ];
      startupWMClass = "ResponsivelyApp";
    })
  ];

  passthru = { inherit nodejs electron; };
  meta = {
    description = "Browser for testing responsive layouts across multiple devices";
    homepage = "https://responsively.app";
    license = [ lib.licenses.mit lib.licenses.agpl3Only ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "responsively";
  };
})
