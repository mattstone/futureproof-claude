if Rails.env.development?
  require 'amazing_print'
  
  # Configure amazing_print for beautiful console output
  AmazingPrint.defaults = {
    indent: 2,
    color: {
      array:      :white,
      bigdecimal: :blue,
      class:      :yellow,
      date:       :cyan,
      falseclass: :red,
      fixnum:     :blue,
      float:      :blue,
      hash:       :gray,
      keyword:    :cyan,
      method:     :purple,
      nilclass:   :red,
      rational:   :blue,
      string:     :yellow,
      struct:     :gray,
      symbol:     :cyan,
      time:       :cyan,
      trueclass:  :green,
      variable:   :cyan
    }
  }
end