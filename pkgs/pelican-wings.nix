{
  lib,
  buildGoModule,
  fetchFromGitHub,
}: let
  pname = "wings";
  version = "1.0.0-beta9";
in
  buildGoModule {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "pelican-dev";
      repo = "wings";
      tag = "v${version}";
      sha256 = "sha256-bYIQAPBC7vLFLEJRYcuk8h2OgNZCrzQgP3hxK/f9Lv4=";
    };

    vendorHash = "sha256-kf0WPAIKtiUW/sWEhwTyptmnJheFQxiQSB2IEKml2FU=";
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
