describe 'Game menu - Skyrim SE' do

  before do
    # Register the key sequence getting to the desired menu
    entering_menu_keys %w[KEY_ENTER]
    exiting_menu_keys %w[KEY_ESCAPE]
  end

  it 'installs skse64 in the game' do
    mock_web(
      'https://skse.silverlock.org/' => 'skse.silverlock.org/index.html',
      'https://skse.silverlock.org/beta/skse64_2_02_03.7z' => 'skse.silverlock.org/skse64_2_00_19.7z'
    )
    mock_system_calls [
      [%r{"7z.exe" x "[^"]*/modsvaskr/skse64.7z" -o"[^"]*/modsvaskr/skse64" -r}, proc do |cmd|
        skse64_tmp_dir = cmd.match(%r{"7z.exe" x "[^"]*/modsvaskr/skse64.7z" -o"([^"]*/modsvaskr/skse64)" -r})[1]
        FileUtils.mkdir_p "#{skse64_tmp_dir}/skse64"
        File.write("#{skse64_tmp_dir}/skse64/mocked_skse64.txt", 'Dummy content')
      end]
    ]
    with_game_dir do
      with_tmp_dir('7-Zip') do |seven_zip_dir|
        run_modsvaskr(
          config: {
            'games' => [
              {
                'name' => 'Skyrim SE',
                'path' => game_dir,
                'type' => 'skyrim_se',
                'launch_exe' => 'skyrim_se_launcher.exe'
              }
            ],
            '7zip' => seven_zip_dir
          },
          keys: %w[KEY_DOWN KEY_ENTER]
        ) do
          expect(File.exist?("#{game_dir}/mocked_skse64.txt")).to be true
        end
      end
    end
    expect_logs_to_include(/SKSE64 installed successfully./)
  end

end
