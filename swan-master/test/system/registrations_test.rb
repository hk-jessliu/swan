require "application_system_test_case"

class RegistrationsTest < ApplicationSystemTestCase
  setup do
    @registration = registrations(:one)
  end

  test "visiting the index" do
    visit registrations_url
    assert_selector "h1", text: "Registrations"
  end

  test "creating a Registration" do
    visit registrations_url
    click_on "New Registration"

    fill_in "Access token", with: @registration.access_token
    fill_in "Name", with: @registration.name
    fill_in "Otp", with: @registration.otp
    fill_in "Salt master", with: @registration.salt_master
    fill_in "Swan backend", with: @registration.swan_backend
    click_on "Create Registration"

    assert_text "Registration was successfully created"
    click_on "Back"
  end

  test "updating a Registration" do
    visit registrations_url
    click_on "Edit", match: :first

    fill_in "Access token", with: @registration.access_token
    fill_in "Name", with: @registration.name
    fill_in "Otp", with: @registration.otp
    fill_in "Salt master", with: @registration.salt_master
    fill_in "Swan backend", with: @registration.swan_backend
    click_on "Update Registration"

    assert_text "Registration was successfully updated"
    click_on "Back"
  end

  test "destroying a Registration" do
    visit registrations_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Registration was successfully destroyed"
  end
end
