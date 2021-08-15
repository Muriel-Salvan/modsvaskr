describe 'Main menu' do

  it 'displays the menu when configuration is empty' do
    run_modsvaskr
    expect_logs_to_include(/Launch Modsvaskr UI v#{Modsvaskr::VERSION}/)
  end

  it 'displays the version in the menu title' do
    run_modsvaskr
    expect_menu_title_to_include(/Modsvaskr v#{Modsvaskr::VERSION}/)
  end

  it 'displays a new version norification in the menu title' do
    mock_system_calls(
      [
        [
          'gem list modsvaskr --remote',
          <<~EOS

            *** REMOTE GEMS ***

            modsvaskr (999.1.0)
          EOS
        ]
      ],
      add_init_mocks: false
    )
    run_modsvaskr
    expect_menu_title_to_include(/New version available: 999.1.0/)
  end

  it 'displays several games sub-menus' do
    run_modsvaskr(config: {
      'games' => [
        {
          'name' => 'Test Game 1',
          'path' => '/path/to/test_game_1',
          'type' => 'test_game',
          'launch_exe' => 'game_launcher.exe'
        },
        {
          'name' => 'Test Game 2',
          'path' => '/path/to/test_game_2',
          'type' => 'test_game',
          'launch_exe' => 'game_launcher.exe'
        },
        {
          'name' => 'Test Game 3',
          'path' => '/path/to/test_game_3',
          'type' => 'test_game',
          'launch_exe' => 'game_launcher.exe'
        }
      ]
    })
    expect_menu_items_to_include('Test Game 1')
    expect_menu_items_to_include('Test Game 2')
    expect_menu_items_to_include('Test Game 3')
  end

  it 'initializes the game plugin when used' do
    initialized = false
    ModsvaskrTest::Games::TestGame.init_proc = proc do
      initialized = true
    end
    run_modsvaskr(config: {
      'games' => [
        {
          'name' => 'Test Game',
          'path' => '/path/to/test_game',
          'type' => 'test_game',
          'launch_exe' => 'game_launcher.exe'
        }
      ]
    })
    expect(initialized).to eq true
  end

  it 'fails when the game type from the config is unknown' do
    expect do
      run_modsvaskr(config: {
        'games' => [
          {
            'name' => 'Test Game',
            'path' => '/path/to/test_game',
            'type' => 'unknown_game_type',
            'launch_exe' => 'game_launcher.exe'
          }
        ]
      })
    end.to raise_error(/Unknown game type: unknown_game_type. Available ones are .*test_game.*/)
  end

end
