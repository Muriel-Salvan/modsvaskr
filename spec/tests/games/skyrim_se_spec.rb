describe 'Game menu - Skyrim SE' do

  before(:each) do
    # Register the key sequence getting to the desired menu
    entering_menu_keys %w[KEY_ENTER]
    exiting_menu_keys %w[KEY_ESCAPE]
  end

  it 'installs skse64 in the game' do
    mock_web(
      'https://skse.silverlock.org/' => 'skse.silverlock.org/index.html',
      'https://skse.silverlock.org/beta/skse64_2_00_19.7z' => 'skse.silverlock.org/skse64_2_00_19.7z'
    )
    mock_system_calls [
      ['"7z.exe" x "/tmp/modsvaskr/skse64.7z" -o"/tmp/modsvaskr/skse64" -r', proc do
        FileUtils.mkdir_p '/tmp/modsvaskr/skse64/skse64'
        File.write('/tmp/modsvaskr/skse64/skse64/mocked_skse64.txt', 'Dummy content')
      end]
    ]
    with_game_dir do |game_dir|
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
          expect(File.exist?("#{game_dir}/mocked_skse64.txt")).to eq true
        end
      end
    end
    expect_logs_to_include(/SKSE64 installed successfully./)
  end

end
