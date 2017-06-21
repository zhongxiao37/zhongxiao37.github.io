module SudoProcessor


    # SudoManager holds a list of Sudo to be process
    # It will also split itself into multiple possible Sudo when trying different possibles
    class SudoManager
        attr_accessor :result_list, :debug

        def initialize(data)
            @result_list = []
            @result_list << Sudo.new(data)
        end

        def process

            i = 0
            while true

                @result_list = process_core(@result_list)
                i = i +1
                puts "Round #{i}: #{completed}" if @debug

                if completed
                    break
                else
                    @result_list = generate_for_first_possible(@result_list)
                end

                break if i >= 9 #exit after 10 rounds
            end

        end

        def show_results
            @result_list.each { |e| e.show_results if e.valid? }
        end

        # check if the whole list is completed
        def completed
            is_complete = true
            @result_list.each do |r|
                if !r.completed?
                    is_complete = false
                    break
                end
            end
            is_complete
        end

        private

        # input: a list of sudo array
        # output: a list of sudo array after processed
        def process_core(array)
            _result_list = []
            array.each do |e|
                e.process
                _result_list << e
            end
            # populate result list with new result
            _result_list
        end

        # generate the possible Sudo for first possible cell

        def generate_for_first_possible(array)
            _result_list = []

            array.each do |sudo_arr|
                i, j = get_first_possible_index(sudo_arr)
                first_possible_cell = sudo_arr[i][j]
                p "possible cell #{i}-#{j}: #{first_possible_cell}" if @debug
                first_possible_cell.each do |t|
                    new_array = sudo_arr.dup.tap do |arr|
                        arr[i][j] = t
                    end
                    _result_list << Sudo.new(new_array)
                end
            end

            _result_list
        end

        def get_first_possible_index(array)
            i, j = nil, nil
            found = false
            array.each_with_index do |row, row_index|
                row.each_with_index do |cell, col_index|
                    if [*cell].count > 1
                        i = row_index
                        j = col_index
                        found = true
                        break
                    end
                    break if found
                end
                break if found
            end
            return i, j
        end
    end

    class Sudo < Array
        attr_accessor :debug, :results

        def initialize(data)
            super(data)
            @debug = false
        end

        # avoid of Array dup since updating will also affect original varaible
        def dup
            self.map { |e| e.map { |i| i } }
        end

        def process
            @results = SudoProcessor.process_runner(self)
        end


        def show_results
            puts "Completed: #{completed?} - Valid: #{valid?}"
            results.each do |t|
                p t
            end
        end

        def valid?
            valid_result = true
            row_valid, col_valid, box_valid = false, false, false
            # valid if sudo result for each row, col, box
            (1..9).to_a.each do |index|
                row_valid = ((1..9).to_a - SudoProcessor.get_nums_in_row(self, index-1).compact).empty?
                col_valid = ((1..9).to_a - SudoProcessor.get_nums_in_col(self, index-1).compact).empty?
                box_valid = ((1..9).to_a - SudoProcessor.get_nums_in_box(self, index).flatten.compact).empty?

                if row_valid and col_valid and box_valid
                    # go to next loop if valid
                else
                    valid_result = false
                    break
                end
            end

            valid_result
        end


        def completed?
            is_complete = false

            # ideally, you won't see duplicate values
            # if you see duplicate, then it's all over: completed
            if valid? or has_duplicate_values
                is_complete = true
            end

            is_complete
        end


        def has_duplicate_values
            already_invalid = false
            self.each_with_index do |row, row_index|
                row.each_with_index do |cell, col_index|
                    row_numbers = SudoProcessor.get_nums_in_row(self, row_index).compact
                    col_numbers = SudoProcessor.get_nums_in_col(self, col_index).compact
                    box_numbers = SudoProcessor.get_nums_in_box(self, SudoProcessor.get_box_index(row_index, col_index)).flatten.compact

                    # if current row/col/box already has duplicate value
                    # do nothing
                    if row_numbers.uniq.count < row_numbers.count
                        puts "Row #{row_index} is invalid" if @debug
                        already_invalid = true
                        break
                    end
                    if col_numbers.uniq.count < col_numbers.count
                        puts "Column #{col_index} is invalid" if @debug
                        already_invalid = true
                        break
                    end
                    if box_numbers.uniq.count < box_numbers.count
                        puts "Box #{get_box_index(row_index, col_index)} is invalid" if @debug
                        already_invalid = true
                        break
                    end
                end
                break if already_invalid
            end
            already_invalid
        end

    end

    # box_index the array has 9 boxes totally
    def self.get_nums_in_box(array, box_index)
        numbers = []
        # box_index = 5, then [col_index, row_index] = [3, 3]
        col_index = (box_index-1)%3*3
        row_index = (box_index-1)/3*3
        numbers += array[row_index][col_index..col_index+2]
        numbers += array[row_index+1][col_index..col_index+2]
        numbers += array[row_index+2][col_index..col_index+2]
        numbers.select { |e| [*e].count == 1 }
    end


    def self.get_nums_in_row(array, row_index)
        array[row_index][0..8].select { |e| [*e].count == 1 }
    end

    def self.get_nums_in_col(array, col_index)
        array.map { |e| e[col_index] }.select { |e| [*e].count == 1 }
    end

    def self.get_box_index(row_index, col_index)
        row_index/3*3+col_index/3+1
    end

    def self.get_possible_nums_in_box_except_one_cell(array, row_index, col_index)
        numbers = []
        box_index = get_box_index(row_index, col_index)
        col_index_start = (box_index-1)%3*3
        row_index_start = (box_index-1)/3*3

        numbers += array[row_index_start][col_index_start..col_index_start+2].dup
        numbers += array[row_index_start+1][col_index_start..col_index_start+2].dup
        numbers += array[row_index_start+2][col_index_start..col_index_start+2].dup

        # except specific cell
        cell_index = (row_index - row_index_start)*3 + (col_index - col_index_start)
        numbers[cell_index] = nil

        # filter out filled cells
        numbers.select { |e| [*e].count > 1 }
    end

    def self.get_possible_nums_in_row_except_one_cell(array, row_index, col_index)
        numbers = array[row_index].dup

        # except specific cell
        cell_index = col_index
        numbers[cell_index] = nil

        # filter out filled cells
        numbers.select { |e| [*e].count > 1 }
    end

    def self.get_possible_nums_in_col_except_one_cell(array, row_index, col_index)
        numbers = []
        numbers = array.map { |e| e[col_index] }.dup

        # except specific cell
        cell_index = row_index
        numbers[cell_index] = nil

        # filter out filled cells
        numbers.select { |e| [*e].count > 1 }
    end

    def self.process_step_one_core(array)

        processed = false
        possible_nums = []

        # if current row/col/box already has duplicate value
        # do nothing
        if array.has_duplicate_values
            return array, processed
        end

        # check the possible numbers in each row, col and box
        # if there is only one choice, then it's the answer
        # also re-populate the possible numbers

        array_ = array.dup
        array_.each_with_index do |row, row_index|
            row.each_with_index do |cell, col_index|
                row_numbers = get_nums_in_row(array_, row_index).compact
                col_numbers = get_nums_in_col(array_, col_index).compact
                box_numbers = get_nums_in_box(array_, get_box_index(row_index, col_index)).flatten.compact

                if cell.nil? or [*cell].count > 1
                    possible_nums = (1..9).to_a -
                        row_numbers -
                        col_numbers -
                        box_numbers
                    if possible_nums.count == 1
                        array[row_index][col_index] = possible_nums[0]
                        processed = true
                    elsif possible_nums.count > 1
                        array[row_index][col_index] = possible_nums
                    end
                end

            end
        end

        return array, processed
    end

    def self.process_step_one(array)

        processed = false
        possible_nums = []

        while true
            array, processed = process_step_one_core(array)
            break if !processed #break if no cell is processed
        end

        array
    end

    def self.process_step_two(array)

        processed = false
        possible_nums = []

        # 排除法 如果某一数字只能够出现在某一格，那就只有这种可能
        # 需要预先clean一次已经填上的数字

        array.each_with_index do |row, row_index|
            row.each_with_index do |cell, col_index|
                if [*cell].count > 1
                    # 当前box内所有有多个可能性的cell
                    possible_nums = cell - get_possible_nums_in_box_except_one_cell(array, row_index, col_index).flatten

                    if possible_nums.count == 1
                        array[row_index][col_index] = possible_nums[0]
                        array = process_step_one(array)
                        processed = true
                    end

                    possible_nums = cell - get_possible_nums_in_row_except_one_cell(array, row_index, col_index).flatten

                    if possible_nums.count == 1
                        array[row_index][col_index] = possible_nums[0]
                        array = process_step_one(array)
                        processed = true
                    end

                    possible_nums = cell - get_possible_nums_in_col_except_one_cell(array, row_index, col_index).flatten

                    if possible_nums.count == 1
                        array[row_index][col_index] = possible_nums[0]
                        array = process_step_one(array)
                        processed = true
                    end
                end
            end
        end

        return array, processed
    end

    def self.process_step_three(array)

        processed = false
        possible_nums = []
        # Advance method
        # 如果两个可能数字出现在一行/列中的两个cell内，则该行/列其他cell不可能再出现这两个数字

        only_two_possible_nums = []
        only_two_possible_num = []
        array.each_with_index do |row, row_index|
            only_two_possible_nums = row.select { |e| [*e].count == 2 }
            if only_two_possible_nums.count == 2 and only_two_possible_nums.uniq.count == 1
                only_two_possible_num = only_two_possible_nums.uniq.flatten

                row.each_with_index do |cell, col_index|
                    if [*cell].count > 2
                        possible_nums = cell - only_two_possible_num
                        if possible_nums.count == 1
                            array[row_index][col_index] = possible_nums[0]
                            processed = true
                        elsif  possible_nums.count > 1
                            array[row_index][col_index] = possible_nums
                        end
                    end
                end
            end

        end

        array.each_with_index do |row, col_index|
            col = array.map { |c| c[col_index] }
            only_two_possible_nums = col.select { |e| [*e].count == 2 }
            if only_two_possible_nums.count == 2 and only_two_possible_nums.uniq.count == 1
                only_two_possible_num = only_two_possible_nums.uniq.flatten

                col.each_with_index do |cell, row_index|
                    if [*cell].count > 2
                        possible_nums = cell - only_two_possible_num
                        if possible_nums.count == 1
                            array[row_index][col_index] = possible_nums[0]
                            processed = true
                        elsif  possible_nums.count > 1
                            array[row_index][col_index] = possible_nums
                        end
                    end
                end
            end

        end

        return array, processed

    end

    def self.process_runner(array)

        while true
            processed = false

            array = process_step_one(array)

            array, processed = process_step_two(array)

            next if processed

            array, processed = process_step_three(array)

            next if processed

            break if !processed #break if no cell is processed
        end

        array
    end

end