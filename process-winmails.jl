using XLSX
using DataFrames

df = DataFrame(mailname = String[], mail = String[], number = Int[], type = String[], code = String[])
folder = "mails"
mailfnames = readdir(folder)

for mailfname in mailfnames
  open(joinpath(folder, mailfname), "r") do f
    print(".")
    src = read(f, String)
    mail = match(r"(\w+\+\w+@gmail.com)", src).captures[1]
    number = parse(Int, match(r"(\d)+ Richtige", src).captures[1])
    type = match(r"Gewinn: (.*)", src).captures[1]
    code = ""
    push!(df, (mailfname, mail, number, type, code))
  end
end

XLSX.writetable("data.xlsx", collect(DataFrames.eachcol(df)), DataFrames.names(df))
