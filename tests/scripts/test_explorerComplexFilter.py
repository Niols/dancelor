from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC

import utils

class TestExplorerComplexFilter():
  def setup_method(self, method):
    utils.default_setup(self)

  def teardown_method(self, method):
    utils.default_teardown(self)

  def test_explorerComplexFilter(self):
    self.driver.get("http://localhost:8080/explore?q=tam")
    self.driver.find_element(By.XPATH, "//button[text()[contains(., 'Filter')]]").click()
    self.driver.find_element(By.XPATH, "//label[contains(text(), 'Book')]").click()
    self.driver.find_element(By.XPATH, "//button[text()[contains(., 'Apply')]]").click()
    self.driver.find_element(By.XPATH, "//div[contains(text(), 'Showing 1 to 1 of 1 entries')]")
    self.driver.find_element(By.XPATH, "//button[text()[contains(., 'Filter')]]").click()
    self.driver.find_element(By.XPATH, "//label[contains(text(), 'Tune')]").click()
    self.driver.find_element(By.XPATH, "//label[contains(text(), 'Polka')]").click()
    self.driver.find_element(By.XPATH, "//label[contains(text(), 'Waltz')]").click()
    self.driver.find_element(By.XPATH, "//button[text()[contains(., 'Apply')]]").click()
    self.driver.find_element(By.XPATH, "//*[contains(text(), 'Your search returned no result')]")
    self.wait.until(EC.text_to_be_present_in_element((By.CSS_SELECTOR, ".alert-warning"), "Your search returned no results."))
    assert self.driver.find_element(By.XPATH, "//div[@class = 'container-md']//input").get_attribute("value") \
      == "type:tune kind:polka,waltz tam "
