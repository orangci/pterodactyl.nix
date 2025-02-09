{
  lib,
  buildGo123Module,
  fetchFromGitHub,
}: let
  pname = "pterodactyl-wings";
  version = "1.11.13";
in
  buildGo123Module {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "pterodactyl";
      repo = "wings";
      tag = "v${version}";
      sha256 = "sha256-UpYUHWM2J8nH+srdKSpFQEaPx2Rj2+YdphV8jJXcoBU=";
    };

    vendorHash = "sha256-eWfQE9cQ7zIkITWwnVu9Sf9vVFjkQih/ZW77d6p/Iw0=";
    subPackages = ["."];

    ldflags = [
      "-X github.com/pterodactyl/wings/system.Version=${version}"
    ];

    meta = {
      changelog = "https://github.com/pterodactyl/wings/blob/${version}/CHANGELOG.md";
      description = "The server control plane for Pterodactyl Panel.";
      homepage = "https://github.com/pterodactyl/wings";
      license = lib.licenses.mit;
      mainProgram = "wings";
      platforms = lib.platforms.linux;
    };
  }
