describe 'Logs menu' do

  before do
    # Register the key sequence getting to the desired menu
    entering_menu_keys %w[KEY_ENTER]
    exiting_menu_keys %w[KEY_ESCAPE]
    menu_index_to_test 1
  end

  it 'displays logs' do
    run_modsvaskr
    expect_menu_items_to_include(/Launch Modsvaskr UI v#{Modsvaskr::VERSION}/)
  end

end
