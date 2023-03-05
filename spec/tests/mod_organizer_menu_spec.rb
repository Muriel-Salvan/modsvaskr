require 'modsvaskr_test/mocked_mod_organizer/mod_organizer'

describe 'Mod Organizer menu' do

  before do
    # Register the key sequence getting to the desired menu
    entering_menu_keys %w[KEY_ENTER]
    exiting_menu_keys %w[KEY_ESCAPE]
    menu_index_to_test 1
  end

  it 'displays the ModOrganizer menu' do
    run_modsvaskr_with_mo(
      mods: {
        'TestMod1' => {},
        'TestMod2' => { enabled: false },
        'TestMod3' => {}
      }
    )
    expect_menu_items_to_include('Run Mod Organizer')
    expect_menu_items_to_include('3 mods (2 enabled)')
  end

  it 'runs ModOrganizer' do
    mocked_mo = ModsvaskrTest::MockedModOrganizer::ModOrganizer.new
    expect(ModOrganizer).to receive(:new).with('/path/to/mo', hash_including(instance_name: 'TestMOInstance')).and_return(mocked_mo)
    run_modsvaskr(
      config: {
        'mod_organizer' => {
          'installation_dir' => '/path/to/mo',
          'instance_name' => 'TestMOInstance'
        }
      },
      keys: %w[KEY_ENTER]
    )
    expect(mocked_mo.run_called).to be(true)
  end

  describe 'in the mods list menu' do

    before do
      # Register the key sequence getting to the desired menu
      entering_menu_keys %w[KEY_ENTER KEY_DOWN KEY_ENTER]
      exiting_menu_keys %w[KEY_ESCAPE KEY_ESCAPE]
      menu_index_to_test 2
    end

    it 'displays the ordered list of mods' do
      run_modsvaskr_with_mo(
        mods: {
          'TestMod1' => {},
          'TestMod2' => { enabled: false },
          'TestMod3' => {}
        }
      )
      expect_menu_item_to_include(0, /^\[X\] 0 TestMod1/)
      expect_menu_item_to_include(1, /^\[ \] 1 TestMod2/)
      expect_menu_item_to_include(2, /^\[X\] 2 TestMod3/)
    end

    it 'displays mod categories' do
      run_modsvaskr_with_mo(
        mods: {
          'TestMod1' => {
            categories: %w[Cat1 Cat2]
          }
        }
      )
      expect_menu_item_to_include(0, '[Cat1] [Cat2]')
    end

    it 'displays the mod\'s number of plugins' do
      run_modsvaskr_with_mo(
        mods: {
          'TestMod1' => {
            plugins: %w[plugin1.esp plugin2.esp]
          }
        }
      )
      expect_menu_item_to_include(0, '2 plugins')
    end

    it 'displays NexusMod\'s sources having downloads, sorted by download date' do
      run_modsvaskr_with_mo(
        mods: {
          'TestMod1' => {
            sources: [
              {
                type: :nexus_mods,
                nexus_mod_id: 42,
                download: {
                  nexus_file_name: 'mod42_file.7z',
                  downloaded_date: Time.parse('2023-01-05')
                }
              },
              {
                type: :nexus_mods,
                nexus_mod_id: 43,
                download: {
                  nexus_file_name: 'mod43_file.7z',
                  downloaded_date: Time.parse('2023-01-04')
                }
              }
            ]
          }
        }
      )
      expect_menu_item_to_include(0, 'Nexus Mod 43/mod43_file.7z + Nexus Mod 42/mod42_file.7z')
    end

    it 'displays NexusMod\'s sources missing downloads' do
      run_modsvaskr_with_mo(
        mods: {
          'TestMod1' => {
            sources: [
              {
                type: :nexus_mods,
                nexus_mod_id: 42,
                file_name: 'mod42_local_file.7z',
                download: nil
              }
            ]
          }
        }
      )
      expect_menu_item_to_include(0, 'Nexus Mod 42/mod42_local_file.7z')
    end

    it 'displays NexusMod\'s sources missing downloads and local files' do
      run_modsvaskr_with_mo(
        mods: {
          'TestMod1' => {
            sources: [
              {
                type: :nexus_mods,
                nexus_mod_id: 42,
                file_name: nil,
                download: nil
              }
            ]
          }
        }
      )
      expect_menu_item_to_include(0, 'Nexus Mod 42/<Unknown file>')
    end

    it 'displays unknown sources having files' do
      run_modsvaskr_with_mo(
        mods: {
          'TestMod1' => {
            sources: [
              {
                type: :unknown,
                file_name: 'mod_local_file.7z'
              }
            ]
          }
        }
      )
      expect_menu_item_to_include(0, 'mod_local_file.7z')
    end

    it 'displays unknown sources missing files' do
      run_modsvaskr_with_mo(
        mods: {
          'TestMod1' => {
            sources: [
              {
                type: :unknown,
                file_name: nil
              }
            ]
          }
        }
      )
      expect_menu_item_to_include(0, '<Unknown source>')
    end

    it 'displays mixed sources' do
      run_modsvaskr_with_mo(
        mods: {
          'TestMod1' => {
            sources: [
              {
                type: :nexus_mods,
                nexus_mod_id: 42,
                download: {
                  nexus_file_name: 'mod42_file.7z',
                  downloaded_date: Time.parse('2023-01-05')
                }
              },
              {
                type: :unknown,
                file_name: 'mod_local_file.7z'
              }
            ]
          }
        }
      )
      expect_menu_item_to_include(0, 'mod_local_file.7z + Nexus Mod 42/mod42_file.7z')
    end

    it 'displays no source' do
      run_modsvaskr_with_mo(
        mods: {
          'TestMod1' => {
            sources: []
          }
        }
      )
      expect_menu_item_to_include(0, /TestMod1\s+0 plugins/)
    end

    it 'visits the mod\'s URL' do
      expect(Launchy).to receive(:open).with('https://test_mod1_url.com')
      run_modsvaskr_with_mo(
        mods: {
          'TestMod1' => {
            url: 'https://test_mod1_url.com'
          }
        },
        keys: %w[v]
      )
    end

  end

end
