module SudoProcessor

    class Sudo < Array
        attr_accessor :debug, :results

        def initalize(data)
            super(data)
            self.debug = false
        end

        def dup
            self.map { |e| e.map { |i| i } }
        end

        def process
            i = 0
            processed = true
            while processed
                self.results, processed = SudoProcessor.process_runner(self)

                i += 1

                break if !processed #break if no cell is processed
            end
            puts "Finished in #{i} rounds" if self.debug
        end


        def show_results
            results.each do |t|
                p t
            end
        end

        def valid?
            valid_result = true
            row_valid, col_valid, box_valid = false, false, false
            # valid if sudo result
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

        # check the possible numbers in each row, col and box
        # if there is only one choice, then it's the answer
        # also re-populate the possible numbers

        array_ = array.dup
        array_.each_with_index do |row, row_index|
            row.each_with_index do |cell, col_index|
                if cell.nil? or [*cell].count > 1
                    possible_nums = (1..9).to_a -
                        get_nums_in_row(array_, row_index).compact -
                        get_nums_in_col(array_, col_index).compact -
                        get_nums_in_box(array_, get_box_index(row_index, col_index)).flatten.compact
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

        processed = false
        possible_nums = []

        array = process_step_one(array)

        array, processed = process_step_two(array)

        array = process_step_one(array)

        array, processed = process_step_three(array)

        return array, processed
    end

end