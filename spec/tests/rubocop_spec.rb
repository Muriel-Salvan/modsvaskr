require 'json'

describe 'Coding guidelines' do

  it 'makes sure code style follow Rubocop guides' do
    rubocop_report = JSON.parse(`bundle exec rubocop --format json`)
    expect(rubocop_report['summary']['offense_count']).to(
      eq(0),
      proc do
        # Format a great error message to help
        wrong_files = rubocop_report['files'].reject { |file_info| file_info['offenses'].empty? }
        <<~EO_ERROR
          #{wrong_files.size} files have Rubocop issues:
          #{
            wrong_files.map do |file_info|
              offenses = file_info['offenses'].map { |offense_info| "L#{offense_info['location']['start_line']}: #{offense_info['cop_name']} - #{offense_info['message']}" }
              "* #{file_info['path']}:#{
                if offenses.size == 1
                  " #{offenses.first}"
                else
                  " #{offenses.size} offenses:\n#{offenses.map { |offense| "  - #{offense}" }.join("\n")}"
                end
              }"
            end.join("\n")
          }
        EO_ERROR
      end
    )
  end

end
