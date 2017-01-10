
Then(/^Table step with param (.*)$/) do |param|
  p "table step with param: "+param
end
Then(/^Table step2 with param (.*)$/) do |param|
  p "table step2 with param: "+param
end
Then(/^Not table step$/) do
  p "not table step"
end