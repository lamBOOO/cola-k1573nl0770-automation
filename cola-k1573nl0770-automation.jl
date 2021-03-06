using WebDriver
using YAML
using JSON
using Dates
using Gumbo
using Cascadia

function init_session(s :: Session)
  navigate!(s, "https://kistenlotto.cocacola.de")
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
  delete!(s, "") # delete cookies
  script!(s, "localStorage.clear();")
  script!(s, "sessionStorage.removeItem('cds-current-user-uuid');")
  init_session(s)
end

function login(s :: Session, cfg, i :: Int)
  logout(s)
  email = string(cfg["gmail_id"], "+A$(lpad(i, 6, "0"))@gmail.com")
  pw = cfg["pw"]

  # click account btn
  click!(Element(s, "xpath", """//*[@id="app"]/div/div/div[1]/div[4]/div[1]/button"""))
  sleep(2)
  # input credentials
  element_keys!(Element(s, "xpath", """//*[@id="signInEmailAddress"]"""), email)
  element_keys!(Element(s, "xpath", """//*[@id="currentPassword"]"""), pw)
  # click signin btn
  sleep(1)
  click!(Element(s, "xpath", """//*[@id="ces-form-submit-ces-sign-in-form"]"""))

  # accept tos if not already done
  sleep(3)
  # TODO ADAPTIVELY WAIT HERE
  try
    click!(Element(s, "xpath", """//*[@id="app"]/div/div[2]/div[2]/div[2]/div[2]/div[3]/button"""))
    @info "TOS accepted"
  catch e
    @info "TOS already accepted"
  end

  try
    sleep(2)
    @info "UUID: $(getuuid(s))"
  catch e
    throw(ErrorException("Login failed"))
  end
end

function getuuid(s)
  ls = collect(keys(script!(s, "return localStorage")))
  ls_names = map(x->string(x), ls)
  ls_uuids = filter(x->x!=nothing, match.(r"terms_(.*)", ls_names))
  @assert length(ls_uuids) == 1
  uuid = ls_uuids[1].captures[1]
  return uuid
end

function getcsrftoken(s)
  html = parsehtml(source(s))
  csrftoken = eachmatch(Selector("head > meta:nth-child(4)"), html.root)[1].attributes["content"]
  return csrftoken
end

function cratelottery_cookie(s)
  cratelottery = cookie(s, "cratelottery").value
end

function xsrftoken_cookie(s)
  cratelottery = cookie(s, "XSRF-TOKEN").value
end

"""
TODO: Fix API calls
"""
function remainding_tries(s::Session)
  uuid = getuuid(s)

  cmd = Cmd([
    "curl", "https://kistenlotto.cocacola.de/api/v1/users/remaining-tries",
    "-H", "x-csrf-token: $(getcsrftoken(s))",
    "-H", "content-type: application/json;charset=UTF-8",
    "-H", "referer: https://kistenlotto.cocacola.de/",
    "-H", "cookie: cratelottery=$(cratelottery_cookie(s))",
    "--data-binary", "{\"uuid\":\"$uuid\"}"
  ])
  response = JSON.parse(read(pipeline(cmd, stderr=Base.DevNull()), String))
  @debug "Response: $response"
  return response["data"]["remaining_tries"]
end

function apply(s)
  for i=1:remainding_tries(s)
    @info "Apply number $i"
    apply_once(s)
  end
end

function apply_once(s::Session)
  navigate!(s, "https://kistenlotto.cocacola.de")

  # apply btn
  click!(Element(s, "xpath", """//*[@id="app"]/div/div/main/div/div/div/div[2]/div/button"""))

  # image input field
  im_field = Element(s, "xpath", """//*[@id="img-file"]""")
  element_keys!(im_field, joinpath(pwd(), cfg["cola_crate_image"]))

  # use image btn
  click!(Element(s, "xpath", """//*[@id="app"]/div/div/main/div/div/div/div/div/div/div/div[3]/div[2]/button"""))

  # wait for analysis
  analysis_done = false
  print("Analysis")
  for i=1:20
    answer_el = Element(s, "xpath", """//*[@id="app"]/div/div/main/div/div/div/div/div/div""")
    if occursin("UND JETZT GUT MISCHEN!", element_text(answer_el))
      @info "Analysis done"
      analysis_done = true
      break
    else
      print(".")
      sleep(3)
    end
  end
  @assert analysis_done

  # use api to apply
  apply_api(s)

end

"""
Only works when image is already analyzed.
FIXME: Needs recaptcha solve
"""
function apply_api(s::Session)
  # skip the clicking part and directly use API 🤯
  tries_avail = remainding_tries(s)
  uuid = getuuid(s)
  options = ["coke_red", "coke_zero", "coke_zero_coffeine", "coke_vanilla", "coke_cherry", "coke_light", "coke_light_no_coffeine", "coke_light_lemon", "fanta", "fanta_light", "fanta_red", "fanta_green", "fanta_lemon", "mezzomix", "mezzomix_zero", "sprite", "sprite_zero", "lift"]

  if tries_avail > 0
    rdm_crate = [rand(options) for i=1:12]
    @info "Apply with crate: $rdm_crate"
    cmd = Cmd([
      "curl", "https://kistenlotto.cocacola.de/api/v1/users/submit-crate",
      "-H", "x-csrf-token: $(getcsrftoken(s))",
      "-H", "content-type: application/json;charset=UTF-8",
      "-H", "referer: https://kistenlotto.cocacola.de/mitmachen/haendler",
      "-H", "cookie: cookie: XSRF-TOKEN=$(xsrftoken_cookie(s));cratelottery=$(cratelottery_cookie(s))",
      "--data-binary", "{\"retailer\":\"rewe\",\"uuid\":\"$uuid\",\"crate\":$rdm_crate, \"imageUploads\":[{\"attempt\":1,\"success\":true}]}"
    ])
    response = JSON.parse(read(pipeline(cmd, stderr=Base.DevNull()), String))
    @info "Response: $response"
    @info response["data"]["message"]
  end

  @assert remainding_tries(s) == tries_avail-1
end

function register(s :: Session, s2 :: Session, cfg, i)
  navigate!(s, "https://kistenlotto.cocacola.de")
  sleep(2)
  email = string(cfg["gmail_id"], "+A$(lpad(i, 6, "0"))@gmail.com")

  # click account btn
  click!(Element(s, "xpath", """//*[@id="app"]/div/div/div[1]/div[4]/div[1]/button"""))
  # click new account btn
  sleep(2)
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
end

function handle2Captcha(s, s2, cfg)
  captcha_el = Element(s, "xpath", """//*[@id="recaptcha"]""")
  sitekey = element_attr(captcha_el, "data-sitekey")

  submit_link = string("http://2captcha.com/in.php?key=", cfg["2captcha_userkey"], "&method=userrecaptcha&googlekey=", sitekey, "&pageurl=", current_url(s))
  navigate!(s2, submit_link)

  # Check if submitted
  answer = element_text(Element(s2, "xpath", """/html/body"""))
  cap_id = match(r"OK\|(.*)", answer).captures[1]
  @info "Captcha ID $cap_id"

  receive_link = string("http://2captcha.com/res.php?key=", cfg["2captcha_userkey"], "&action=get&id=", cap_id)
  cap_solved = false
  cap_response = nothing
  print("Captcha")
  while !cap_solved
    navigate!(s2, receive_link)
    answer = element_text(Element(s2, "xpath", """/html/body"""))
    @debug answer
    if answer=="CAPCHA_NOT_READY"
      print(".")
      sleep(10)
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

function activate(s, cfg, i)
  email = string(cfg["gmail_id"], "+A$(lpad(i, 6, "0"))@gmail.com")

  # wait for email to come
  email_arrived = false
  latest_msg = ""
  print("Activation mail")
  for count=1:30
    latest_msg = read(`python3 get-latest-inbox-gmail.py`, String)
    # print(latest_msg)
    if occursin(email, latest_msg) # latest email is correct one
      @info "Activation email arived"
      email_arrived = true
      break
    else
      print(".")
      sleep(2)
    end
  end
  @assert email_arrived

  code = match(r"verification_code=(\w*)", latest_msg).captures[1]
  code = replace(code, "3D" => "") # remove leading "3D"

  activation_link = "https://kistenlotto.cocacola.de/verification?verification_code=$(code)"
  @info activation_link

  sleep(2)
  navigate!(s, activation_link)
  sleep(2)
end

function register_all(s, s2, cfg)
  for i=cfg["gmail_start"]:cfg["gmail_end"]
    logout(s)
    @info "Register $i"
    register(s, s2, cfg, i)
  end
end

function apply_all(s, cfg)
  init_session(s)
  for i=cfg["gmail_start"]:cfg["gmail_end"]
    @info "Login and apply $i"
    login(s, cfg, i)
    apply(s)
  end
end

function fullautomation(s, s2, cfg)
  retries = 10
  init_session(s)
  for i=cfg["gmail_start"]:cfg["gmail_end"]
    @info now()
    @info "Account number $i"

    register_ok = false
    activate_ok = false
    apply_ok = false

    for j=1:retries
      @info "Try number $j"

      try
        logout(s)
        @info "Logout: OK"
      catch e
        if !isa(e, InterruptException)
          @info "Logout: FAIL"
          print(e)
        else
          error("Interupt")
        end
      end

      if !register_ok
        try
          register(s, s2, cfg, i)
          @info "Register: OK"
          register_ok = true
        catch e
          if !isa(e, InterruptException)
            @info "Register: FAIL"
            print(e)
          else
            error("Interupt")
          end
        end
      end

      if !activate_ok
        try
          activate(s, cfg, i)
          @info "Activate: OK"
          activate_ok = true
        catch e
          if !isa(e, InterruptException)
            @info "Activate: FAIL"
            print(e)
          else
            error("Interupt")
          end
        end
      end

      try
        login(s, cfg, i)
        @info "Login: OK"
      catch e
        if !isa(e, InterruptException)
          @info "Login: FAIL"
          print(e)
        else
          error("Interupt")
        end
      end

      if !apply_ok
        try
          apply(s)
          @info "Apply: OK"
          apply_ok = true
        catch e
          if !isa(e, InterruptException)
            @info "Apply: FAIL"
            print(e)
          else
            error("Interupt")
          end
        end
      end

      try
        if remainding_tries(s) == 0
          @info "SUCCES"
          break
        end
      catch e
        @warn "NO SUCCESS - RETRY"
      end

    end
  end
end

rwd = RemoteWebDriver(Capabilities(
  "chrome",
  timeouts = Timeouts(script = 50_000, pageLoad = 100_000, implicit = 5_000)
), host = "127.0.0.1", port = 4444)
s = Session(rwd)
s2 = Session(rwd)
cfg = YAML.load_file("config.yml")
