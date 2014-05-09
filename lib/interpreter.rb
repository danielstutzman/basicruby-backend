class Interpreter
  class AssertionFailed < RuntimeError
  end

  class DebuggerDoesntYetSupport < RuntimeError
  end

  def assert bool
    raise AssertionFailed if !bool
  end

  def no feature
    raise DebuggerDoesntYetSupport.new(feature)
  end

  def initialize main, start_pos_to_end_pos
    @main = main
    @start_pos_to_end_pos = start_pos_to_end_pos
  end

  def self.start
    {
      pos: [0],
      result: [], # it's actually a stack, should always have 0 or 1 values
      partial_calls: [],
      output: '',
      vars: {},
      ifs: [], # a stack of bools recording conditions of nested ifs
    }
  end

  def advance state, ast
    state = state.clone
    locator, progress = state[:pos][0...-1], state[:pos][-1]
    sexp = locate_sexp locator, ast
    todos =
      if sexp.nil?
        [[:set_result, nil], [:exit]]
      else case sexp[0]
        when :block   then interpret_block   sexp, progress
        when :int     then interpret_int     sexp, progress
        when :str     then interpret_str     sexp, progress
        when :true    then interpret_true    sexp, progress
        when :false   then interpret_false   sexp, progress
        when :nil     then interpret_nil     sexp, progress
        when :float   then interpret_float   sexp, progress
        when :call    then interpret_call    sexp, progress
        when :arglist then interpret_arglist sexp, progress
        when :paren   then interpret_paren   sexp, progress
        when :lasgn   then interpret_lasgn   sexp, progress
        when :lvar    then interpret_lvar    sexp, progress
        when :if      then interpret_if      sexp, progress
        when :dstr    then interpret_dstr    sexp, progress
        when :evstr   then interpret_evstr   sexp, progress
        else no "s-exp with head #{sexp[0]}"
      end
    end

    todos.each do |todo|
      do_todo todo, state
    end
    state
  end
  def do_todo todo, state
    case todo[0]
    when :start_call
      state[:partial_calls].push []
    when :push_arg
      new_partial_calls = state[:partial_calls].clone
      partial_call = new_partial_calls.last
      raise 'Hit bottom of result stack' if state[:result].size == 0
      partial_call.push state[:result].pop
      state[:partial_calls] = new_partial_calls
    when :enter
      state[:pos] = state[:pos] + [0]
    when :exit
      if state[:pos][0...-1] == []
        state[:pos] = nil # done with program
      else
        state[:pos] = state[:pos][0...-2] + [state[:pos][-2] + 1]
      end
    when :call
      new_partial_calls = state[:partial_calls].clone
      receiver, method_name, *args = new_partial_calls.pop
      results = do_call receiver, method_name, args
      state[:result].push results[:new_result]
      state[:output] += results[:new_output]
      state[:partial_calls] = new_partial_calls
    when :set_result
      state[:result].push todo[1]
    when :next
      advance_pos(state)
    when :assign_to
      var_name = todo[1]
      raise 'Hit bottom of result stack' if state[:result].size == 0
      value = state[:result].pop
      state[:vars][var_name] = value
      state[:result].push value
    when :pop_result
      raise 'Hit bottom of result stack' if state[:result].size == 0
      state[:result].pop
    when :lookup_var
      var_name = todo[1]
      state[:result].push state[:vars][var_name]
    when :push_if
      raise 'Hit bottom of result stack' if state[:result].size == 0
      state[:ifs].push state[:result].pop
    when :enter_if
      if state[:ifs].last == todo[1] # compare the two bools
        state[:pos] = state[:pos] + [0] # enter
      else
        advance_pos(state)
      end
    when :pop_if
      raise 'Hit bottom of ifs stack' if state[:ifs].size == 0
      state[:ifs].pop
    when :highlight
      p [todo[0], todo[1], @start_pos_to_end_pos[todo[1]]]
    else
      no "todo with head #{todo[0]}"
    end
  end
  def do_call receiver, method_name, args
    if receiver == @main && method_name == :puts
      if args.size == 0
        output = "\n"
      else
        output = args.map { |arg| "#{arg}\n" }.join
      end
      result = nil
    elsif receiver == @main && method_name == :p
      if args.size == 0
        output = ""
        result = nil
      elsif args.size == 1
        output = "#{args[0].inspect}\n"
        result = args[0]
      else
        output = args.map { |arg| "#{arg.inspect}\n" }.join
        result = args
      end
    elsif receiver == @main && method_name == :__STR_INTERP
      output = ''
      result = args.map { |arg| "#{arg}" }.join
    else
      output = ''
      result = receiver.send(method_name, *args)
    end
    { new_output: output, new_result: result }
  end
  def advance_pos state
    locator, progress = state[:pos][0...-1], state[:pos][-1]
    state[:pos] = locator + [progress + 1]
  end
  def locate_sexp locator, sexp
    if locator == []
      sexp
    else
      head, *tail = locator
      locate_sexp tail, sexp[head]
    end
  end
  def interpret_block sexp, progress
    if progress == 0 # :block
      [[:next]]
    elsif progress < sexp.size
      if progress == 1
        [[:enter]]
      else
        [[:pop_result], [:enter]]
      end
    else
      [[:exit]]
    end
  end
  def interpret_int sexp, progress
    case progress
      when 0 then [[:next]] # :int
      when 1 then [[:highlight, sexp.source], [:set_result, sexp[1]], [:next]]
      when 2 then [[:exit]]
    end
  end
  def interpret_str sexp, progress
    case progress
      when 0 then [[:next]] # :str
      when 1 then [[:highlight, sexp.source], [:set_result, sexp[1]], [:next]]
      when 2 then [[:exit]]
    end
  end
  def interpret_true sexp, progress
    case progress
      when 0 then [[:next]] # :true
      when 1 then [[:highlight, sexp.source], [:set_result, true], [:exit]]
    end
  end
  def interpret_false sexp, progress
    case progress
      when 0 then [[:next]] # :false
      when 1 then [[:highlight, sexp.source], [:set_result, false], [:exit]]
    end
  end
  def interpret_nil sexp, progress
    case progress
      when 0 then [[:next]] # :nil
      when 1 then [[:highlight, sexp.source], [:set_result, nil], [:exit]]
    end
  end
  def interpret_float sexp, progress
    case progress
      when 0 then [[:next]] # :float
      when 1 then [[:set_result, sexp[1]], [:next]]
      when 2 then [[:highlight, sexp.source], [:exit]]
    end
  end
  def interpret_call sexp, progress
    case progress
      when 0 # :call
        [[:start_call], [:next]]
      when 1 # receiver
        if sexp[1]
          [[:enter]]
        else
          [[:set_result, @main], [:next]]
        end
      when 2 # method_name
        [[:push_arg], [:set_result, sexp[2]], [:push_arg], [:next]]
      when 3 # arglist
        [[:enter]]
      when 4
        [[:highlight, sexp.source], [:call], [:exit]]
    end
  end
  def interpret_arglist sexp, progress
    if progress == 0 # :arglist
      [[:next]]
    elsif progress < sexp.size
      if progress == 1
        [[:enter]]
      else
        [[:push_arg], [:enter]]
      end
    else
      if sexp.size > 1
        [[:push_arg], [:exit]]
      else
        [[:exit]]
      end
    end
  end
  def interpret_paren sexp, progress
    case progress
      when 0 then [[:next]]
      when 1 then [[:enter]]
      when 2 then [[:exit]]
    end
  end
  def interpret_lasgn sexp, progress
    case progress
      when 0 then [[:next]] # :lasgn
      when 1 then [[:next]] # varname
      when 2 then [[:enter]] # expr
      when 3 then [[:highlight, sexp.source], [:assign_to, sexp[1]], [:exit]]
    end
  end
  def interpret_lvar sexp, progress
    case progress
      when 0 then [[:next]] # :lvar
      when 1 # varname
        [[:highlight, sexp.source], [:lookup_var, sexp[1]], [:next]]
      when 2 then [[:exit]]
    end
  end
  def interpret_if sexp, progress
    case progress
      when 0 then [[:next]] # :if
      when 1 then [[:enter]] # condition
      when 2 # block for true
        [[:push_if], [:enter_if, true]]
      when 3 # block for false
        [[:enter_if, false]]
      when 4 then [[:pop_if], [:exit]]
    end
  end
  def interpret_dstr sexp, progress
    if progress == 0 # :dstr
      [[:start_call], [:set_result, @main], [:push_arg],
       [:set_result, :__STR_INTERP], [:push_arg], [:next]]
    elsif progress == 1
      [[:set_result, sexp[1]], [:next]]
    elsif progress < sexp.size
      [[:push_arg], [:enter]]
    else
      [[:push_arg], [:call], [:exit]]
    end
  end
  def interpret_evstr sexp, progress
    case progress
      when 0 then [[:next]] # :evstr
      when 1 then [[:enter]] # expression
      when 2 then [[:exit]]
    end
  end
end
