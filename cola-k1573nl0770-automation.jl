using REPL.TerminalMenus
import REPL
using Dates
using WebDriver
using YAML
# using Gumbo
# using Cascadia


function init_session(s :: Session)
  navigate!(s, "https://kistenlotto.cocacola.de")
  try
    sleep(2)
    cookie_btn = Element(s, "xpath", """//*[@id="onetrust-accept-btn-handler"]""")
    click!(cookie_btn)
    @info "Cookies accepted"
  catch e
    @info "Cookies already accepted"
  end

end

function register(s :: Session, s2 :: Session, cfg, i)
  navigate!(s, "https://kistenlotto.cocacola.de")
  sleep(2)
  email = string(cfg["gmail_id"], "+A$(lpad(i, 6, "0"))@gmail.com")

  # click account btn
  click!(Element(s, "xpath", """//*[@id="app"]/div/div/div[1]/div[4]/div[1]/button"""))
  # click new account btn
  click!(Element(s, "xpath", """//*[@id="app"]/div/div[2]/div[2]/div[2]/div[2]/div/div/div[6]/button/div"""))
  # enter details
  element_keys!(Element(s, "xpath", """//*[@id="firstName"]"""), cfg["firstname"])
  element_keys!(Element(s, "xpath", """//*[@id="lastName"]"""), cfg["lastname"])
  element_keys!(Element(s, "xpath", """//*[@id="birthdate_day"]"""), lpad(cfg["birth_dd"],2,"0"))
  element_keys!(Element(s, "xpath", """//*[@id="birthdate_month"]"""), lpad(cfg["birth_mm"],2,"0"))
  element_keys!(Element(s, "xpath", """//*[@id="birthdate_year"]"""), lpad(cfg["birth_yyyy"],2,"0"))
  element_keys!(Element(s, "xpath", """//*[@id="emailAddress"]"""), email)
  element_keys!(Element(s, "xpath", """//*[@id="newPassword"]"""), cfg["pw"])
  element_keys!(Element(s, "xpath", """//*[@id="newPasswordConfirm"]"""), cfg["pw"])
  element_keys!(Element(s, "xpath", """//*[@id="addressStreetAddress1"]"""), cfg["street"])
  element_keys!(Element(s, "xpath", """//*[@id="addressCity"]"""), cfg["city"])
  element_keys!(Element(s, "xpath", """//*[@id="addressPostalCode"]"""), cfg["zipcode"])
  # gender = other
  click!(Element(s, "xpath", """//*[@id="gender"]/option[4]"""))
  # handle 2captcha
  handle2Captcha(s, s2, cfg)
  # click submit_button
  click!(Element(s, "xpath", """//*[@id="ces-form-submit-ces-register-form"]"""))

  try
    success_el = Element(s, "xpath", """//*[@id="app"]/div/div[2]/div[2]/div[2]/div[2]/div/div""")
    match(r"", element_text(success_el)).match
    @info "Register: Done"
  catch e
    @info "Register: Fail"
  end

end

function handle2Captcha(s, s2, cfg)
  captcha_el = Element(s, "xpath", """//*[@id="recaptcha"]""")
  sitekey = element_attr(captcha_el, "data-sitekey")

  submit_link = string("http://2captcha.com/in.php?key=", cfg["2captcha_userkey"], "&method=userrecaptcha&googlekey=", sitekey, "&pageurl=", current_url(s))
  navigate!(s2, submit_link)

  # Check if submitted
  answer = element_text(Element(s2, "xpath", """/html/body"""))
  cap_id = match(r"OK\|(.*)", answer).captures[1]
  @info cap_id

  receive_link = string("http://2captcha.com/res.php?key=", cfg["2captcha_userkey"], "&action=get&id=", cap_id)
  cap_solved = false
  cap_response = nothing
  while !cap_solved
    navigate!(s2, receive_link)
    answer = element_text(Element(s2, "xpath", """/html/body"""))
    @debug answer
    if answer=="CAPCHA_NOT_READY"
      @info "Captcha wait"
      sleep(20)
    else
      @info "Captcha done"
      cap_response = match(r"OK\|(.*)", answer).captures[1]
      cap_solved = true
    end
  end
  @debug cap_response

  # process initial page
  script!(s, string("document.getElementById(\"g-recaptcha-response\").innerHTML=\"", cap_response, "\";"))
  script!(s, "onCaptchaSubmit()")

end

rwd = RemoteWebDriver(Capabilities("chrome"), host = "127.0.0.1", port = 4444)
sleep(1)
s = Session(rwd)
s2 = Session(rwd)
cfg = YAML.load_file("config.yml")

