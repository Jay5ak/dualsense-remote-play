class DualsenseRemotePlay < Formula
  desc "Opens PS Remote Play when a DualSense controller connects"
  homepage "https://github.com/YOUR-USER/dualsense-remote-play"
  url "https://github.com/YOUR-USER/dualsense-remote-play/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_RELEASE_SHA256"
  license "MIT"

  depends_on xcode: :build

  def install
    system "./Scripts/build-app.sh"
    prefix.install "build/DualSense Remote Play.app"
    bin.write_exec_script prefix/"DualSense Remote Play.app/Contents/MacOS/DualSenseRemotePlay"
  end

  def caveats
    <<~EOS
      Start the app once with:
        open "#{opt_prefix}/DualSense Remote Play.app"
    EOS
  end
end
