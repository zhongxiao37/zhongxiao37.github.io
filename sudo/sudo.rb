
require_relative 'lib/sudo_processor'


initial_array = SudoProcessor::Sudo.new([
	[nil,nil,nil,nil,nil,nil,nil,nil,nil],
	[nil,nil,nil,nil,nil,nil,nil,nil,nil],
	[nil,nil,nil,nil,nil,nil,nil,nil,nil],
	[nil,nil,nil,nil,nil,nil,nil,nil,nil],
	[nil,nil,nil,nil,nil,nil,nil,nil,nil],
	[nil,nil,nil,nil,nil,nil,nil,nil,nil],
	[nil,nil,nil,nil,nil,nil,nil,nil,nil],
	[nil,nil,nil,nil,nil,nil,nil,nil,nil],
	[nil,nil,nil,nil,nil,nil,nil,nil,nil]
				])

initial_array = SudoProcessor::Sudo.new([
	[nil, 7 ,nil,nil,nil,nil,nil, 6 ,nil],
	[ 6 , 8 , 9 , 7 ,nil,nil,nil, 2 , 1 ],
	[nil,nil, 1 ,nil,nil,nil,nil,nil,nil],
	[nil,nil,nil,nil,nil, 5 , 6 ,nil,nil],
	[ 7 ,nil,nil,nil,nil,nil,nil,nil, 4 ],
	[ 4 ,nil, 2 ,nil,nil,nil, 1 , 8 , 5 ],
	[nil,nil,nil,nil,nil,nil,nil, 9 ,nil],
	[ 5 ,nil,nil, 4 ,nil, 8 ,nil,nil, 7 ],
	[nil, 1 ,nil,nil,nil,nil, 2 ,nil,nil]
				])

# [2, 7, 5, 9, 1, 4, 8, 6, 3]
# [6, 8, 9, 7, 5, 3, 4, 2, 1]
# [3, 4, 1, 6, 8, 2, 7, 5, 9]
# [1, 9, 3, 8, 4, 5, 6, 7, 2]
# [7, 5, 8, 2, 6, 1, 9, 3, 4]
# [4, 6, 2, 3, 7, 9, 1, 8, 5]
# [8, 3, 4, 1, 2, 7, 5, 9, 6]
# [5, 2, 6, 4, 9, 8, 3, 1, 7]
# [9, 1, 7, 5, 3, 6, 2, 4, 8]


puts "Initial array"
initial_array.debug = true
initial_array.each { |e| p e }

initial_array.process

initial_array.show_results

# if above process could not figure out the answer completely, try different possibles
if !initial_array.completed?

	initial_array = SudoProcessor::SudoManager.new(initial_array.dup)

	initial_array.process

	puts "Final after multiple tries:"
	initial_array.show_results
end