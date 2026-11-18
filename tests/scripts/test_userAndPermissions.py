import pytest
import json
import html
import time
from urllib.parse import urlparse

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.support import expected_conditions
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities

import utils

class TestUserAndPermissions():
  def setup_method(self, method):
    utils.default_setup(self)

  def teardown_method(self, method):
    utils.default_teardown(self)

  def load_entry(self):
    ## Access the entry page of a private set.
    self.driver.get("http://localhost:8080/set/view/wrwk-cz9g-g3wi")

  def is_404(self):
    self.driver.find_element(By.XPATH, "//*[contains(text(), 'Oooops')]")

  def is_entry(self):
    self.driver.find_element(By.XPATH, "//*[contains(text(), 'A Private Set')]")

  def sign_in(self, remember_me=False):
    ## Find the “Sign in” button in the header.
    self.driver.find_element(By.XPATH, "//button[text()[contains(., 'Sign in')]]").click()
    ## Fill the form and submit.
    self.driver.find_element(By.XPATH, "//input[@placeholder = 'JeanMilligan']").send_keys("Niols")
    self.driver.find_element(By.XPATH, "//input[@placeholder = '1234567']").send_keys("test")
    if remember_me:
      ## Find the label, follow it to its input element. Click the element via
      ## JavaScript because the input element is hidden.
      for_ = self.driver.find_element(By.XPATH, "//label[text()[contains(., 'Remember me')]]").get_attribute("for")
      self.driver.execute_script("arguments[0].click();", self.driver.find_element(By.ID, for_))
    self.driver.find_element(By.XPATH, "//button[text()[contains(., 'Sign in')] and not(contains(@class, 'disabled'))]").click()
    ## Wait until we are signed in. Specifically, we want all the requests to be
    ## done, as they all may carry the relevant cookies.
    time.sleep(1)

  def sign_out(self):
    self.driver.find_element(By.XPATH, "//button[text()[contains(., 'Niols')]]").click()
    self.driver.find_element(By.XPATH, "//button[text()[contains(., 'Sign out')]]").click()

  def test_sign_in_permissions_sign_out(self):
    ## Load the page and check that we are not signed in.
    self.load_entry()
    self.is_404()
    ## Sign in, check that we are - sign out, check that we are.
    self.sign_in()
    self.is_entry()
    self.sign_out()
    self.is_404()

  def test_sign_in_remember_me(self):
    ## Load the page and check that we are not signed in.
    self.driver.delete_all_cookies()
    self.load_entry()
    self.is_404()
    ## Sign in, then remove session and reload - check that we are not signed in.
    self.sign_in()
    self.driver.delete_cookie("session")
    self.load_entry()
    self.is_404()
    ## Sign in with “remember me”, then remove session and reload - check that we are signed in.
    self.sign_in(remember_me=True)
    self.driver.delete_cookie("session")
    self.load_entry()
    self.is_entry()
