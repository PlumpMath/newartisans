{ cabal, hakyll, pandoc }:

cabal.mkDerivation (self: {
  pname = "newartisans";
  version = "1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  buildDepends = [ hakyll pandoc ];
  meta = {
    homepage = "http://newartisans.com";
    description = "Lost in Technopolis";
    license = self.stdenv.lib.licenses.bsd3;
  };
})
