require 'sudo_processor'


describe SudoProcessor do

  describe "#get_nums_in_box" do
    context "for box" do
      it "matches" do
        initial_array = SudoProcessor::Sudo.new([
            [6, 1, 7, 4, 5, 2, 3, 8, 9],
            [9, 3, 4, 7, 1, 8, 2, 5, 6],
            [5, 2, 8, 6, 9, 3, 4, 1, 7],
            [2, 7, 9, 8, 6, 4, 1, 3, 5],
            [1, 6, 3, 5, 2, 9, 7, 4, 8],
            [8, 4, 5, 1, 3, 7, 6, 9, 2],
            [3, 5, 2, 9, 7, 1, 8, 6, 4],
            [7, 8, 6, 3, 4, 5, 9, 2, 1],
            [4, 9, 1, 2, 8, 6, 5, 7, 3]
                        ])

        expect(SudoProcessor.get_nums_in_box(initial_array, 1)).to eql([6, 1, 7, 9, 3, 4, 5, 2, 8])

      end
    end
  end

  describe "#get_nums_in_row" do
    context "for row" do
      it "matches" do
        initial_array = SudoProcessor::Sudo.new([
            [6, 1, 7, 4, 5, 2, 3, 8, 9],
            [9, 3, 4, 7, 1, 8, 2, 5, 6],
            [5, 2, 8, 6, 9, 3, 4, 1, 7],
            [2, 7, 9, 8, 6, 4, 1, 3, 5],
            [1, 6, 3, 5, 2, 9, 7, 4, 8],
            [8, 4, 5, 1, 3, 7, 6, 9, 2],
            [3, 5, 2, 9, 7, 1, 8, 6, 4],
            [7, 8, 6, 3, 4, 5, 9, 2, 1],
            [4, 9, 1, 2, 8, 6, 5, 7, 3]
                        ])

        expect(SudoProcessor.get_nums_in_row(initial_array, 1)).to eql([9, 3, 4, 7, 1, 8, 2, 5, 6])

      end
    end
  end

  describe "#get_nums_in_col" do
    context "for column" do
      it "matches" do
        initial_array = SudoProcessor::Sudo.new([
            [6, 1, 7, 4, 5, 2, 3, 8, 9],
            [9, 3, 4, 7, 1, 8, 2, 5, 6],
            [5, 2, 8, 6, 9, 3, 4, 1, 7],
            [2, 7, 9, 8, 6, 4, 1, 3, 5],
            [1, 6, 3, 5, 2, 9, 7, 4, 8],
            [8, 4, 5, 1, 3, 7, 6, 9, 2],
            [3, 5, 2, 9, 7, 1, 8, 6, 4],
            [7, 8, 6, 3, 4, 5, 9, 2, 1],
            [4, 9, 1, 2, 8, 6, 5, 7, 3]
                        ])

        expect(SudoProcessor.get_nums_in_col(initial_array, 3)).to eql([4, 7, 6, 8, 5, 1, 9, 3, 2])

      end
    end
  end


  describe "#get_box_index" do
    context "box 1" do
      it "matches" do

        expect(SudoProcessor.get_box_index(0, 0)).to eql(1) #0, 0 should be in box 1
        expect(SudoProcessor.get_box_index(2, 2)).to eql(1) #0, 0 should be in box 1
        expect(SudoProcessor.get_box_index(0, 2)).to eql(1) #0, 0 should be in box 1
        expect(SudoProcessor.get_box_index(2, 0)).to eql(1) #0, 0 should be in box 1

      end
    end
    context "box 6" do
      it "matches" do

        expect(SudoProcessor.get_box_index(7, 4)).to eql(8) #0, 0 should be in box 6

      end
    end
    context "box 8" do
      it "matches" do

        expect(SudoProcessor.get_box_index(7, 4)).to eql(8) #0, 0 should be in box 6

      end
    end
  end


  describe ".valid?" do
    context "valid array" do
      it "matches" do

        initial_array = SudoProcessor::Sudo.new([
            [6, 1, 7, 4, 5, 2, 3, 8, 9],
            [9, 3, 4, 7, 1, 8, 2, 5, 6],
            [5, 2, 8, 6, 9, 3, 4, 1, 7],
            [2, 7, 9, 8, 6, 4, 1, 3, 5],
            [1, 6, 3, 5, 2, 9, 7, 4, 8],
            [8, 4, 5, 1, 3, 7, 6, 9, 2],
            [3, 5, 2, 9, 7, 1, 8, 6, 4],
            [7, 8, 6, 3, 4, 5, 9, 2, 1],
            [4, 9, 1, 2, 8, 6, 5, 7, 3]
                        ])

        expect(initial_array.valid?).to eql(true)

      end
    end
    context "invalid array" do
      it "matches" do

        initial_array = SudoProcessor::Sudo.new([
            [6, 1, 7, 4, 5, 2, 3, 8, 9],
            [9, 3, 4, 7, 1, 8, 2, 5, 6],
            [5, 2, 8, 6, 9, 3, 4, 1, 7],
            [2, 7, 9, 8, 6, 4, 1, 3, 5],
            [1, 6, 3, 5, 2, 9, 7, 4, 8],
            [8, 4, 5, 1, 3, 7, 6, 9, 2],
            [3, 5, 2, 9, 7, 1, 2, 6, 4],
            [7, 8, 6, 3, 4, 5, 9, 2, 1],
            [4, 9, 1, 2, 8, 6, 5, 7, 3]
                        ])

        expect(initial_array.valid?).to eql(false)

      end
    end
  end

  describe ".process" do
    context "junior level" do
      it "matches" do
        initial_array = SudoProcessor::Sudo.new([
            [nil,nil,nil,nil,nil,nil,  4,nil,  2],
            [nil,nil,  9,  1,nil,nil,nil,  7,nil],
            [nil,nil,  5,nil,  3,  8,nil,nil,nil],
            [  8,nil,nil,  6,  2,  3,nil,  5,nil],
            [nil,  2,nil,nil,  4,  7,nil,nil,  9],
            [  6,  4,  3,  5,nil,  1,nil,nil,nil],
            [nil,  1,  2,  3,  5,nil,nil,  4,  8],
            [nil,  6,  4,  2,  8,  9,  7,nil,  5],
            [  9,nil,  8,  7,  1,nil,nil,  3,  6]
                ])
        initial_array_result = SudoProcessor::Sudo.new([
            [1, 3, 6, 9, 7, 5, 4, 8, 2],
            [4, 8, 9, 1, 6, 2, 5, 7, 3],
            [2, 7, 5, 4, 3, 8, 6, 9, 1],
            [8, 9, 7, 6, 2, 3, 1, 5, 4],
            [5, 2, 1, 8, 4, 7, 3, 6, 9],
            [6, 4, 3, 5, 9, 1, 8, 2, 7],
            [7, 1, 2, 3, 5, 6, 9, 4, 8],
            [3, 6, 4, 2, 8, 9, 7, 1, 5],
            [9, 5, 8, 7, 1, 4, 2, 3, 6]
                        ])

        initial_array.process
        expect(initial_array.results).to eql(initial_array_result)

      end
    end


    context "normal level" do
      it "matches" do
        initial_array = SudoProcessor::Sudo.new([
            [nil, 1 , 7 ,nil,nil,nil, 3 ,nil,nil],
            [nil,nil, 4 ,nil,nil,nil,nil,nil, 6 ],
            [ 5 , 2 ,nil,nil,nil,nil, 4 , 1 ,nil],
            [nil,nil,nil,nil, 6 , 4 ,nil, 3 , 5 ],
            [ 1 ,nil,nil,nil, 2 ,nil, 7 , 4 ,nil],
            [nil, 4 ,nil, 1 , 3 ,nil,nil, 9 ,nil],
            [ 3 , 5 ,nil, 9 ,nil,nil,nil,nil,nil],
            [ 7 ,nil, 6 ,nil,nil,nil,nil,nil,nil],
            [nil, 9 , 1 ,nil,nil, 6 ,nil,nil, 3 ]
                ])
        initial_array_result = SudoProcessor::Sudo.new([
            [6, 1, 7, 4, 5, 2, 3, 8, 9],
            [9, 3, 4, 7, 1, 8, 2, 5, 6],
            [5, 2, 8, 6, 9, 3, 4, 1, 7],
            [2, 7, 9, 8, 6, 4, 1, 3, 5],
            [1, 6, 3, 5, 2, 9, 7, 4, 8],
            [8, 4, 5, 1, 3, 7, 6, 9, 2],
            [3, 5, 2, 9, 7, 1, 8, 6, 4],
            [7, 8, 6, 3, 4, 5, 9, 2, 1],
            [4, 9, 1, 2, 8, 6, 5, 7, 3]
                        ])

        initial_array.process
        expect(initial_array.results).to eql(initial_array_result)

      end
    end

    context "advance level" do
      it "matches" do
        initial_array = SudoProcessor::Sudo.new([
            [ 8 ,nil,nil,nil,nil,nil,nil,nil,nil],
            [nil,nil, 5 ,nil, 9 ,nil,nil, 1 , 7 ],
            [nil,nil,nil, 6 ,nil, 5 , 4 ,nil,nil],
            [nil,nil, 2 , 1 ,nil,nil,nil,nil, 8 ],
            [ 1 ,nil,nil, 8 ,nil, 2 , 7 ,nil, 6 ],
            [nil,nil, 9 , 4 ,nil,nil, 5 ,nil,nil],
            [nil, 2 ,nil,nil,nil, 3 ,nil, 7 , 9 ],
            [nil, 1 ,nil,nil,nil, 7 ,nil,nil, 2 ],
            [nil,nil,nil,nil, 6 ,nil, 8 , 5 ,nil]
                ])
        initial_array_result = SudoProcessor::Sudo.new([
            [8, 3, 1, 7, 2, 4, 9, 6, 5],
            [6, 4, 5, 3, 9, 8, 2, 1, 7],
            [2, 9, 7, 6, 1, 5, 4, 8, 3],
            [7, 6, 2, 1, 5, 9, 3, 4, 8],
            [1, 5, 4, 8, 3, 2, 7, 9, 6],
            [3, 8, 9, 4, 7, 6, 5, 2, 1],
            [4, 2, 6, 5, 8, 3, 1, 7, 9],
            [5, 1, 8, 9, 4, 7, 6, 3, 2],
            [9, 7, 3, 2, 6, 1, 8, 5, 4]
                        ])

        initial_array.process
        expect(initial_array.results).to eql(initial_array_result)

      end
    end
  end


end