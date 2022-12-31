describe 'Game plugins menu' do

  context 'when cleaning plugins' do

    before(:each) do
      entering_menu_keys %w[KEY_ENTER KEY_ENTER]
      exiting_menu_keys %w[KEY_ESCAPE KEY_ESCAPE]
      menu_index_to_test(-3)
    end

    it 'cleans 1 master plugin' do
      with_game_dir do
        with_xedit_dir do
          original_file = "#{game_dir}/Data/test_game.esm"
          FileUtils.mkdir_p "#{game_dir}/Data"
          File.write(original_file, 'Original test_game.esm content')
          mock_system_calls [
            [%r{"SSEEdit.exe" -quickautoclean}, proc do |cmd|
              expect(test_stdout.string.split("\n").last).to eq 'Please double-click on the following plugin: test_game.esm'
              File.write(original_file, 'Cleaned esp content')
            end]
          ]
          run_modsvaskr(
            config: {
              'games' => [
                {
                  'name' => 'Test Game',
                  'path' => game_dir,
                  'type' => 'test_game',
                  'launch_exe' => 'game_launcher.exe',
                  'min_launch_time_secs' => 1,
                  'tests_poll_secs' => 1,
                  'timeout_frozen_tests_secs' => 300
                }
              ],
              'xedit' => xedit_dir
            },
            keys: %w[
              KEY_ENTER
              KEY_END
              KEY_ENTER
            ]
          )
          expected_cleaned_file = "#{game_dir}/Data/cleaned_plugins/test_game.esm"
          expect(File.exist?(original_file))
          expect(File.read(original_file)).to eq 'Original test_game.esm content'
          expect(File.exist?(expected_cleaned_file))
          expect(File.read(expected_cleaned_file)).to eq 'Cleaned esp content'
        end
      end
    end

    it 'cleans several plugins' do
      with_game_dir do
        with_xedit_dir do
          FileUtils.mkdir_p "#{game_dir}/Data"
          File.write("#{game_dir}/Data/test_game.esm", 'Original test_game.esm content')
          File.write("#{game_dir}/Data/mod1.esp", 'Original mod1.esp content')
          File.write("#{game_dir}/Data/mod3.esp", 'Original mod3.esp content')
          mock_system_calls [
            [%r{"SSEEdit.exe" -quickautoclean}, proc do |cmd|
              expect(test_stdout.string.split("\n").last).to eq 'Please double-click on the following plugin: test_game.esm'
              File.write("#{game_dir}/Data/test_game.esm", 'Cleaned test_game.esm content')
            end],
            [%r{"SSEEdit.exe" -quickautoclean}, proc do |cmd|
              expect(test_stdout.string.split("\n").last).to eq 'Please double-click on the following plugin: mod1.esp'
              File.write("#{game_dir}/Data/mod1.esp", 'Cleaned mod1.esp content')
            end],
            [%r{"SSEEdit.exe" -quickautoclean}, proc do |cmd|
              expect(test_stdout.string.split("\n").last).to eq 'Please double-click on the following plugin: mod3.esp'
              File.write("#{game_dir}/Data/mod3.esp", 'Cleaned mod3.esp content')
            end]
          ]
          run_modsvaskr(
            config: {
              'games' => [
                {
                  'name' => 'Test Game',
                  'path' => game_dir,
                  'type' => 'test_game',
                  'launch_exe' => 'game_launcher.exe',
                  'min_launch_time_secs' => 1,
                  'tests_poll_secs' => 1,
                  'timeout_frozen_tests_secs' => 300
                }
              ],
              'xedit' => xedit_dir
            },
            keys: %w[
              KEY_ENTER
              KEY_DOWN
              KEY_DOWN
              KEY_ENTER
              KEY_DOWN
              KEY_DOWN
              KEY_ENTER
              KEY_END
              KEY_ENTER
            ]
          )
          expect(File.read("#{game_dir}/Data/test_game.esm")).to eq 'Original test_game.esm content'
          expect(File.read("#{game_dir}/Data/cleaned_plugins/test_game.esm")).to eq 'Cleaned test_game.esm content'
          expect(File.read("#{game_dir}/Data/mod1.esp")).to eq 'Original mod1.esp content'
          expect(File.read("#{game_dir}/Data/cleaned_plugins/mod1.esp")).to eq 'Cleaned mod1.esp content'
          expect(File.read("#{game_dir}/Data/mod3.esp")).to eq 'Original mod3.esp content'
          expect(File.read("#{game_dir}/Data/cleaned_plugins/mod3.esp")).to eq 'Cleaned mod3.esp content'
        end
      end
    end

  end

end
