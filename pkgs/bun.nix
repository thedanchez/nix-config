{ pkgs, version, hash }:

pkgs.stdenv.mkDerivation {
  pname = "bun";
  inherit version;

  src = pkgs.fetchzip {
    url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64.zip";
    inherit hash;
  };

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [ pkgs.openssl pkgs.stdenv.cc.cc.lib ];

  installPhase = ''
    mkdir -p $out/bin
    install -m 755 bun $out/bin/bun
    ln -s $out/bin/bun $out/bin/bunx
  '';
}
