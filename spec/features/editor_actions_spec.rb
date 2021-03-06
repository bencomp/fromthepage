require 'spec_helper'

describe "editor actions" , :order => :defined do
  Capybara.javascript_driver = :webkit

  before :all do
    @owner = User.find_by(login: OWNER)
    @user = User.find_by(login: USER)
    collection_ids = Deed.where(user_id: @user.id).distinct.pluck(:collection_id)
    @collections = Collection.where(id: collection_ids)
    @collection = @collections.first
    @work = @collection.works.first
    @page = @work.pages.first
    @auth = TranscribeAuthorization.find_by(user_id: @user.id)
  end

  before :each do
    login_as(@user, :scope => :user)
  end    

  it "checks that an editor with permissions can see a restricted work" do
    visit "/display/read_work?work_id=#{@auth.work_id}"
    click_link @work.pages.first.title
    expect(page.find('.tabs')).to have_content("Transcribe")
  end

  it "checks that a restricted editor can't see a work" do
    logout(:user)
    @rest_user = User.find_by(login: REST_USER)
    login_as(@rest_user, :scope => :user)
    visit "/display/read_work?work_id=#{@auth.work_id}"
    click_link @work.pages.first.title
    expect(page.find('.tabs')).not_to have_content("Transcribe")
  end

  it "looks at a collection" do
    visit dashboard_watchlist_path
    page.find('h4', text: @collection.title).click_link(@collection.title)
    expect(page).to have_content("Works")    
    expect(page).to have_content(@work.title)
    expect(page).to have_content("Collection Footer")
    #check the tabs in the collection
    #Subjects
    page.find('.tabs').click_link("Subjects")
    expect(page).to have_content("People")
    expect(page).to have_content("Places")
    #Statistics
    page.find('.tabs').click_link("Statistics")
    expect(page).to have_content("Work Progress")
    #make sure we don't have the owner tabs
    expect(page.find('.tabs')).not_to have_content("Settings")
    expect(page.find('.tabs')).not_to have_content("Export")
    expect(page.find('.tabs')).not_to have_content("Collaborators")

  end

  it "looks at a work" do
    visit collection_path(@collection.owner, @collection)
    click_link @work.title
    expect(page).to have_content(@page.title)
    #Check the tabs in the work
    #About
    page.find('.tabs').click_link("About")
    expect(page).to have_content(@work.title)
    expect(page).to have_content("Description")
    #Versions
    page.find('.tabs').click_link("Versions")
    expect(page).to have_content("Revision 0")
    #Help
    page.find('.tabs').click_link("Help")
    expect(page).to have_content("Transcribing")
    expect(page).to have_content("Linking Subjects")
    #Contents
    page.find('.tabs').click_link("Contents")
    expect(page).to have_content("Page Title")
    expect(page).to have_content(@work.pages.last.title)
    within(page.find('tr', text: @work.pages.last.title)) do
      page.find('a', text: 'Transcribe').click
    end
    expect(page).to have_content("Transcription Conventions")
    expect(page).to have_selector("textarea")

  end

  it "looks at pages" do
    visit collection_read_work_path(@work.collection.owner, @work.collection, @work)
    expect(page).to have_content("please help transcribe this page")
    click_link @page.title
    page.find('#page_source_text')
    expect(page).to have_button('Preview')
    expect(page).to have_content(@page.title)
    expect(page).to have_content("Collection Footer")
    #Versions
    page.find('.tabs').click_link("Versions")
    expect(page).to have_content("revisions")
  end

  it "transcribes a page" do
    visit "/display/display_page?page_id=#{@page.id}"
    expect(page).to have_content("This page is not transcribed")
    page.find('.tabs').click_link("Transcribe")
    expect(page).to have_content("Collection Footer")
    page.fill_in 'page_source_text', with: "Test Preview"
    click_button('Preview')
    expect(page).to have_content('Edit')
    expect(page).to have_content("Test Preview")
    click_button('Edit')
    expect(page).to have_content('Preview')
    page.fill_in 'page_source_text', with: "Test Transcription"
    click_button('Save Changes')
    page.click_link("Overview")
    expect(page).to have_content("Test Transcription")
    expect(page).to have_content("Facsimile")
  end

  it "translates a page" do
    @work = Work.where("supports_translation = ? && restrict_scribes = ?", true, false).first
    visit "/display/display_page?page_id=#{@work.pages.first.id}"
    page.find('.tabs').click_link("Translate")
    expect(page).to have_content("Collection Footer")
    page.fill_in 'page_source_translation', with: "Test Translation Preview"
    click_button('Preview')
    expect(page).to have_content('Edit')
    expect(page).to have_content("Test Translation Preview")
    click_button('Edit')
    expect(page).to have_content('Preview')
    page.fill_in 'page_source_translation', with: "Test Translation"
    click_button('Save Changes')
    expect(page).to have_content("Test Translation")
  end

  it "checks a plain user profile" do
    login_as(@user, :scope => :user)
    visit dashboard_path
    page.find('a', text: 'Your Profile').click
    expect(page).to have_content(@user.display_name)
    expect(page).to have_content("Recent Activity by")
    expect(page).not_to have_selector('.columns')
  end

  it "tries to log in as another user" do
    visit "/users/masquerade/#{@owner.id}"
    expect(page.current_path).to eq dashboard_path
    expect(page.find('.dropdown')).not_to have_content @owner.display_name
    expect(page).to have_content @user.display_name
    expect(page).not_to have_selector('a', text: 'Undo Login As')
  end

  it "adds a note" do
    visit collection_transcribe_page_path(@collection.owner, @collection, @page.work, @page)
    fill_in 'Write a new note...', with: "Test note"
    click_button('Submit')
    expect(page).to have_content "Note has been created"
    click_button('Save Changes')
    expect(page).to have_content('Saved')
  end

  it "tries to save transcription with unsaved note", :js => true do
    col = Collection.second
    test_page = col.works.first.pages.first
    visit collection_transcribe_page_path(col.owner, col, test_page.work, test_page)
    text = Page.find_by(id: test_page.id).source_text
    fill_in('Write a new note...', with: "Test two")
    fill_in 'page_source_text', with: "Attempt to save"
    message = accept_alert do
      click_button('Save Changes')
    end
    expect(message).to have_content("You have unsaved notes.")
    new_text = Page.find_by(id: test_page.id).source_text
    #because of the note, page.source_text should not have changed
    expect(new_text).to eq text
    #save the note
    click_button('Submit')
    expect(test_page.notes.count).not_to be nil
  end

  it "deletes a note", :js => true do
    col = Collection.second
    test_page = col.works.first.pages.first
    visit collection_transcribe_page_path(col.owner, col, test_page.work, test_page)
    title = test_page.notes.last.id
    page.find('.user-bubble_content', text: "Test two")
    page.click_link('', :href => "/notes/#{title}")
    sleep(3)
    expect(Note.find_by(id: title)).to be_nil
  end

end
