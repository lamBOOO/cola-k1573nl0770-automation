using REPL.TerminalMenus
import REPL
using Dates
using WebDriver
using YAML

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

function loggedin(s :: Session)
  navigate!(s, "https://kistenlotto.cocacola.de")
  # login btn
  login_btn = Element(s, "xpath", """//*[@id="app"]/div/div/div[1]/div[4]/div[1]""")
  # check whether login btn has class "hidden" <=> loggedin
  if match(r"hidden", element_attr(login_btn, "class")) != nothing
    return true
  else
    return false
  end
end

function logout(s::Session)
  refresh!(s)
  navigate!(s, "https://kistenlotto.cocacola.de")
  if loggedin(s)
    click!(Element(s, "xpath", """//*[@id="app"]/div/div/div[1]/div[4]/div[2]"""))
  end
end

function login(s :: Session, user :: String, pw::String)
  navigate!(s, "https://kistenlotto.cocacola.de")
  # click account btn
  click!(Element(s, "xpath", """//*[@id="app"]/div/div/div[1]/div[4]/div[1]/button"""))
  # input credentials
  element_keys!(Element(s, "xpath", """//*[@id="signInEmailAddress"]"""), user)
  element_keys!(Element(s, "xpath", """//*[@id="currentPassword"]"""), pw)
  # click signin btn
  click!(Element(s, "xpath", """//*[@id="ces-form-submit-ces-sign-in-form"]"""))

  # accept tos if not already done
  sleep(2)
  try
    click!(Element(s, "xpath", """//*[@id="app"]/div/div[2]/div[2]/div[2]/div[2]/div[3]/button"""))
    @info "TOS accepted"
  catch e
    @info "TOS already accepted"
  end
end

function apply(s :: Session)
  # skip image upload and directly goto mix page 😎
  navigate!(s, "https://kistenlotto.cocacola.de")

  if !loggedin(s)
    throw(ErrorException("Not logged in"))
  end

  # click apply btn
  click!(Element(s, "xpath", """//*[@id="app"]/div/div/main/div/div/div/div[2]/div/button"""))

  # # check if already 3x applied this week from THU:0:00--SUN:23:59
  # sleep(2)
  # msg = element_text(Element(s, "css selector", """#app > div > div.modal.modal-no-remaining-tries > div.modal-content > div.modal-no-remaining-tries"""))
  # # print(msg)
  # sleep(2)
  # if match(r"schon dreimal mitgemacht", msg) != nothing
  # # if true
  #   @info "Already 3x applied"
  #   return
  # end

  # upload cola kiste image not already 3x applied
  sleep(4)
  try
    fileupload_btn = Element(s, "xpath", """//*[@id="img-file"]""")
    element_keys!(fileupload_btn, joinpath(pwd(), cfg["colabox_image"]))
  catch e
    @info "Already 3x applied"
    return nothing
  end

  # click confirm btn
  sleep(2)
  click!(Element(s, "xpath", """//*[@id="app"]/div/div/main/div/div/div/div/div/div/div/div[3]/div[2]/button"""))

  # wait for analysis
  analysis_done = false
  for i=1:15
    msg = element_text(Element(s, "xpath", """//*[@id="app"]/div/div/main/div/div/div/div/div/div"""))
    if match(r"UND JETZT GUT MISCHEN!", msg) != nothing
      analysis_done = true
      break
    else
      sleep(2)
      @info "wait for analysis"
    end
  end
  if analysis_done == false
    throw(ErrorException("Analysis erro"))
  end

  # click submit btn
  sleep(2)
  click!(Element(s, "xpath", """//*[@id="app"]/div/div/main/div/div/div/div/div/div/div[3]/div[1]/button"""))
  # click random retailer
  sleep(2)
  click!(Element(s, "xpath", """//*[@id="app"]/div/div/main/div/div/div/div[1]/div/div[1]"""))
  # click submit btn
  click!(Element(s, "xpath", """//*[@id="app"]/div/div/main/div/div/div/div[2]/div/button"""))

  sleep(2)
  msg = element_text(Element(s, "xpath", """//*[@id="app"]/div/div[2]/div[2]/div[2]/div"""))
  if match(r"Wir haben dir deinen Kistenlottoschein per E-Mail zugeschickt.", msg) == nothing
    throw(ErrorException("Something went wrong"))
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
timeouts!(s, Timeouts(script = 50_000, pageLoad = 100_000, implicit = 5))
sleep(1)
s = Session(rwd)
s2 = Session(rwd)
cfg = YAML.load_file("config.yml")

