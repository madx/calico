class Calico < String

  def to_html(&blk)
    @filter = block_given? ? blk : lambda {|x| x }
    render(parse)
  end

  def parse
    strip!
    delete!("\r")
    split(/\n*^(---.*?^---)\n*|(?:\n\n+)/m).map do |block|
      case block
      when /\A\*\s/
        [:list, list(block)]
      when /\A---/
        [:verb, verb(block)]
      when /\A>\s/
        [:quote, quote(block)]
      else
        [:para, inline(block)]
      end
    end
  end

  private

  def render(tokens)
    tokens.inject([]) { |a, e|
      type, contents = *e
      a << case type
      when :para
        tag :p, contents
      when :verb
        tag :pre, contents
      when :list
        tag :ul, contents
      when :quote
        tag :blockquote, contents
      end
    }.join($/)
  end

  def list(block)
    block.split(/^\* /m)[1..-1].map {|item|
      tag 'li', inline(item)
    }.join($/)
  end

  def quote(block)
    Calico.new(block.gsub(/^>\n/, "\n").gsub(/^> /, '')).to_html
  end

  def verb(block)
    block.gsub(/^---(.*)^---/m) { xml_escape($1.strip, :strict) }
  end

  def inline(text)
     @filter.call xml_escape(text).gsub(/\\\\$/, '<br />').
          gsub(/\\([^\\\n]|\\(?!\n))/) { "&Calico#{$&.unpack("U*")[1]};" }.
          gsub(/&(?!#\d+;|#x[\da-fA-F]+;|\w+;)/, "&amp;").
          gsub(/(`+)(.+?)\1/m,               tag(:code,   '\2')).
          gsub(/_(.+?)_/m,                   tag(:em,     '\1')).
          gsub(/\*(.+?)\*/m,                 tag(:strong, '\1')).
          gsub(/\+(.+?)\+/m,                 tag(:ins,    '\1')).
          gsub(/~(.+?)~/m,                   tag(:del,    '\1')).
          gsub(/!\[([^\]]+)\]\(([^\)]+)\)/m, tag(:img,    nil,
                                                 :src => '\2', :alt => '\1')).
          gsub(/\[([^\]]+)\]\(([^\)]+)\)/m,  tag(:a,
                                                 '\1', :href => '\2')).
          gsub(/&Calico(\d+);/) { [$1.to_i].pack("U*") }.
          strip
  end

  def xml_escape(text, strict=false)
    text.gsub('&') { strict ? '&amp;' : '&' }.
         gsub('<', '&lt;').
         gsub('>', '&gt;').
         gsub('"', '&quot;')
  end

  def tag(t, text, attrs={})
    attrs = attrs.map {|k, v|
      ' %s="%s"' % [k, xml_escape(v, :strict)]
    }.join
    if text
      "<#{t}#{attrs}>#{text}</#{t}>"
    else
      "<#{t}#{attrs} />"
    end
  end

end
