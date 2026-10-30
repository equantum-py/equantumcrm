require "test_helper"

class UrlCanonicalizerTest < ActiveSupport::TestCase
  test "drops tracking params, mobile hosts, fragments and trailing slashes" do
    a = UrlCanonicalizer.canonical("https://m.facebook.com/groups/123/posts/456/?mibextid=abc&utm_source=wa#comments")
    b = UrlCanonicalizer.canonical("https://www.facebook.com/groups/123/posts/456")
    assert_equal "facebook.com/groups/123/posts/456", a
    assert_equal a, b
  end

  test "keeps identifying query params in sorted order" do
    assert_equal "facebook.com/permalink.php?id=2&story_fbid=1",
                 UrlCanonicalizer.canonical("https://facebook.com/permalink.php?story_fbid=1&id=2&fbclid=x")
  end

  test "rejects non http urls" do
    assert_nil UrlCanonicalizer.canonical("javascript:alert(1)")
    assert_not UrlCanonicalizer.http_url?("ftp://example.com")
  end
end
