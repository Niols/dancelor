import os
import html
import subprocess
import json
from selenium.webdriver.common.by import By

import utils

class TestActions():
  def setup_method(self, method):
    utils.default_setup(self)

  def teardown_method(self, method):
    utils.default_teardown(self)

  def get_downloaded_file(self):
    files = [f for f in os.listdir(self.download_dir) if os.path.isfile(os.path.join(self.download_dir, f))]
    if len(files) == 0: raise FileNotFoundError("No files found in the download directory")
    elif len(files) > 1: raise ValueError(f"Multiple files found in the download directory: {files}")
    return os.path.join(self.download_dir, files[0])

  def test_versionShowLilyPond(self):
    self.driver.get("http://localhost:8080/version/view/xzzb-wasm-babe")
    self.driver.find_element(By.XPATH, "(//i[contains(@class, 'bi-three-dots-vertical')])[2]").click()
    self.driver.find_element(By.XPATH, "//*[contains(text(), 'Show LilyPond')]").click()
    expected = subprocess.run(
      ["psql", "--username=dancelor", "--dbname=dancelor", "--tuples-only", "--no-align",
       "--command", "SELECT monolithic_lilypond FROM versions WHERE id = 'xzzb-wasm-babe';"],
      capture_output=True, text=True, check=True,
    ).stdout
    shown = self.driver.find_element(By.XPATH, "//pre[contains(text(), 'clef')]").get_attribute("innerHTML")
    assert(html.unescape(shown.strip()) == expected.strip())
    ## TODO: also check the “copy to clipboard” functionality, but the following
    ## does not work:
    # self.driver.find_element(By.XPATH, "//*[contains(text(), 'Copy to clipboard')]").click()
    # time.sleep(1)  # Wait for clipboard to update
    # copied = pyperclip.paste()
    # assert(copied == expected)
