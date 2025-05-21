class Cwlogs < Formula
  desc "Pretty CloudWatch log CLI viewer with HTML output and highlights"
  homepage "https://github.com/HarveyG/homebrew-cwlogs"
  url "https://github.com/HarveyG/homebrew-cwlogs/archive/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  version "1.0.0"

  def install
    bin.install "bin/cwlogs"
    bin.install "bin/cwlogs_real.sh"
  end
end
