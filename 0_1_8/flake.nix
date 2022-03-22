{
  description = ''Nintendo Switch library libnx for Nim.'';

  inputs.flakeNimbleLib.owner = "riinr";
  inputs.flakeNimbleLib.ref   = "master";
  inputs.flakeNimbleLib.repo  = "nim-flakes-lib";
  inputs.flakeNimbleLib.type  = "github";
  inputs.flakeNimbleLib.inputs.nixpkgs.follows = "nixpkgs";
  
  inputs.src-libnx-0_1_8.flake = false;
  inputs.src-libnx-0_1_8.owner = "jyapayne";
  inputs.src-libnx-0_1_8.ref   = "0_1_8";
  inputs.src-libnx-0_1_8.repo  = "nim-libnx";
  inputs.src-libnx-0_1_8.type  = "github";
  
  inputs."switch-build".owner = "nim-nix-pkgs";
  inputs."switch-build".ref   = "master";
  inputs."switch-build".repo  = "switch-build";
  inputs."switch-build".dir   = "";
  inputs."switch-build".type  = "github";
  inputs."switch-build".inputs.nixpkgs.follows = "nixpkgs";
  inputs."switch-build".inputs.flakeNimbleLib.follows = "flakeNimbleLib";
  
  outputs = { self, nixpkgs, flakeNimbleLib, ...}@deps:
  let 
    lib  = flakeNimbleLib.lib;
    args = ["self" "nixpkgs" "flakeNimbleLib" "src-libnx-0_1_8"];
  in lib.mkRefOutput {
    inherit self nixpkgs ;
    src  = deps."src-libnx-0_1_8";
    deps = builtins.removeAttrs deps args;
    meta = builtins.fromJSON (builtins.readFile ./meta.json);
  };
}