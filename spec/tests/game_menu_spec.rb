describe 'Game menu' do

  before do
    # Register the key sequence getting to the desired menu
    entering_menu_keys %w[KEY_ENTER]
    exiting_menu_keys %w[KEY_ESCAPE]
    menu_index_to_test 1
  end

  it 'displays game information in the menu title and common menu items' do
    run_modsvaskr(
      config: {
        'games' => [
          {
            'name' => 'Test Game',
            'path' => '/path/to/test_game',
            'type' => 'test_game',
            'launch_exe' => 'game_launcher.exe'
          }
        ]
      }
    )
    expect_menu_title_to_include('Test Game')
    expect_menu_items_to_include('Plugins')
    expect_menu_items_to_include('Testing')
  end

  it 'adds game specific menu items' do
    ModsvaskrTest::Games::TestGame.menu_proc = proc do |menu|
      menu.item 'Additional menu item!'
    end
    run_modsvaskr(
      config: {
        'games' => [
          {
            'name' => 'Test Game',
            'path' => '/path/to/test_game',
            'type' => 'test_game',
            'launch_exe' => 'game_launcher.exe'
          }
        ]
      }
    )
    expect_menu_items_to_include('Additional menu item!')
  end

end
