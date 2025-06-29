{
  lib,
  buildGoModule,
  fetchFromGitHub,
}: let
  pname = "wings";
  version = "1.0.0-beta13";
in
  buildGoModule {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "pelican-dev";
      repo = "wings";
      tag = "v${version}";
      sha256 = "sha256-c28cJwFff/UuD6cp5s9vACj8MtN9ysfNKEtjXOFMY+k=";
    };

    vendorHash = "sha256-pxPZZeJpocFzeD0n+KreV+oI2BhL8eZOWFtZDFYOe00=";
    subPackages = ["."];

    ldflags = [
      "-X github.com/pelican-dev/wings/system.Version=${version}"
    ];

    meta = with lib; {
      description = "The server control plane for Pelican Panel.";
      homepage = "https://github.com/pelican-dev/wings";
      license = licenses.mit;
      mainProgram = "wings";
      changelog = "https://github.com/pelican-dev/wings/releases/tag/v${version}";
      platforms = platforms.linux;
    };
  }
