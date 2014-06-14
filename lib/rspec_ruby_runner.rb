require './bytecode_interpreter.rb'
require './bytecode_spool.rb'
require 'opal'

LOG = false

class RspecRubyRunner
  def output_from ruby_code
    parser = Opal::Parser.new
    compiler = AstToBytecodeCompiler.new
    sexp1 = parser.parse BytecodeInterpreter.RUNTIME_PRELUDE
    bytecodes1 = compiler.compile_program 'runtime', sexp1
    bytecodes1.reject! { |bytecode| [:position, :token].include?(bytecode[0]) }
    sexp2 = parser.parse ruby_code
    bytecodes2 = compiler.compile_program 'user', sexp2
    spool = BytecodeSpool.new bytecodes1 + [[:discard]] + bytecodes2

    if LOG
      File.open 'bytecodes.txt', 'w' do |file|
        bytecodes1.each { |bytecode| file.write bytecode.join(' ') + "\n" }
        file.write "\n"
        bytecodes2.each { |bytecode| file.write bytecode.join(' ') + "\n" }
      end
    end

    spool.queue_run_until 'DONE'
    interpreter = BytecodeInterpreter.new
    begin
      File.open 'trace.txt', 'w' do |file|
        while true
        bytecode = spool.get_next_bytecode interpreter.is_result_truthy?,
            interpreter.gosubbing_label, interpreter.gotoing_label,
            interpreter.stack_size
          break if bytecode.nil?
          if LOG
            file.write bytecode.join(' ') + "\n"
          end

          interpreter.interpret bytecode
        end
      end
      interpreter.visible_state[:output].map { |pair| pair[1] }.join
    rescue ProgramTerminated => e
      raise e.cause
    end
  end
end
