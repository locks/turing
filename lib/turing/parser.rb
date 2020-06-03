require 'rubygems'
require 'parslet'
require 'ap'

module Turing
  class Parser
    def self.parse(str)
      new(str).to_configurations
    end

    def initialize(machine_spec)
      @machine_spec = machine_spec
    end

    def split_lines
      lines = @machine_spec.split("\n")
      lines.reject{ |line| line.strip.empty? || line[/^\s*#/] } 
    end
    private :split_lines

    def to_configurations
      split_lines.map{ |line| Line.new(line).to_configuration }
    end

    class Line
      def initialize(line)
        @line = line
      end

      def to_configuration
        state, symbol, actions, end_state = @line.split(/,/).map{|e| e.strip}

        state     = state.intern
        symbol    = parse_symbol(symbol)
        actions   = parse_actions(actions)
        end_state = end_state.intern

        Turing::Machine::Configuration.new(state, symbol, actions, end_state)
      end

      private

      def parse_actions(actions)
        actions = actions.scan /P[^RLE]|R|L|E/
        actions.map do |action|
          case action
          when /P([^RLE])/ then [:write, parse_symbol($1)]
          when "R" then [:right]
          when "L" then [:left]
          when "E" then [:empty]
          end
        end
      end

      def parse_symbol(symbol)
        case symbol
        when "None" then nil
        when "0"    then 0
        when "1"    then 1
        else symbol.intern
        end
      end
    end
  end
  
  class Parslet::Parser
    rule(:eof)  { any.absnt? }
    rule(:char) { match('\w') }

    rule(:space)  { match('\s').repeat(1) }
    rule(:space?) { space.maybe           }

    rule(:comma) { space? >> str(',') >> space? }
  end
  
  class P < Parslet::Parser
    root(:configuration)
    rule(:configuration) { line.repeat(1) }

    rule(:line) do
      label.as(:state)     >> comma >>
      sym.as(:symbol)      >> comma >>
      action.as(:actions)  >> comma >>
      label.as(:end_state) >> (match('\n') | eof)
    end
    
    rule(:label)  { char.as(:char) }
    rule(:sym)    { str('None').as(:value) | char.as(:value) }
    rule(:action) { print.as(:print).maybe >> move.as(:move) }
    
    rule(:print) { str('P') >> char.as(:int) }
    rule(:move)  { str('L').as(:dir) | str('R').as(:dir) | str('E').as(:empty) }
  end
  
  class T < Parslet::Transform
    rule( :state     => simple(:state),
          :symbol    => simple(:sym)  ,
          :actions   => subtree(:ops) ,
          :end_state => simple(:fin)
        ) do
      [ state, sym, ops, fin ]
    end

    # symbol
    rule(:value => 'None')        { nil }
    rule(:value => simple(:char)) { String(char) }
    
    rule(:print => simple(:number),:move => simple(:m)) do
      [ [:print , number] , [m] ]
    end

    rule(:move => simple(:move)) { [Array(move)] }
    rule(:dir => 'L') { :left  }
    rule(:dir => 'R') { :right }
    
    rule(:int  => simple(:i)) { Integer(i)       }
    rule(:char => simple(:c)) { String(c).to_sym }
  end

end

input = <<-HEREDOCS
b, None, P0R, c
c, None, R,   e
e, None, P1R, f
f, None, R,   b
HEREDOCS

res = [
  [ :b, nil, [[ :print, 0 ], [ :right ]], :c ],
  [ :c, nil, [[ :right ]],                :e ],
  [ :e, nil, [[ :print, 1 ], [ :right ]], :f ],
  [ :f, nil, [[ :right ]],                :b ]
]

ap a=Turing::P.new.parse(input)
ap b=Turing::T.new.apply(a)
ap b == res
