
Then(/^Table step with param (.*)$/) do |param|
	#pending("pending in step")
	#raise "step exception"
  p "table step with param: "+param
	sleep 4
end
Then(/^Table step2 with param (.*)$/) do |param|
	#pending("pending in step")
	#raise "step exception"
  p "table step2 with param: "+param
  #raise "shit"
	sleep 3
end
Then(/^Not table step$/) do
  p "not table step"
  sleep 2
end