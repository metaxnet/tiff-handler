require 'tk'

V0 = "1"
HORIZONTAL = "001"
VL1 = "010"
VR1 = "011"
PASS = "0001"
VL2 = "000010"
VR2 = "000011"
VL3 = "0000010"
VR3 = "0000011"
EOL = "000000000001"

CODE_WHITE = 0
CODE_BLACK = 1
VMODES = [V0, VL1, VR1, VL2, VR2, VL3, VR3]
DELTAS = [0, -1, 1, -2, 2, -3, 3]
MODES = [V0, HORIZONTAL, VL1, VR1, VL2, VR2, VL3, VR3, PASS]

PAGE_WIDTH = 1728
BLANK_LINE = "010011011"


def create_black_and_white_dics
	text = File.open("/home/lifman/hello_world/HuffmanFaxCodes.txt").read()
	text = text.gsub(" " , "")
	lines = text.split("\n")
	black = {}
	white = {}
	for i in 0...32
		values = lines[i].split("\t")
		white[values[1] ] = values[0].to_i
		black[values[2] ] = values[0].to_i
		white[values[4] ] = values[3].to_i
		black[values[5] ] = values[3].to_i
        end
	for i in 33...lines.length
		values = lines[i].split("\t")
		white[values[1] ] = values[0].to_i
		black[values[2] ] = values[0].to_i
        end
	return black, white
end

def get_bitstream(filename)
	text = File.open(filename, "rb").read()
	byte_order_indication = text[0...2]
	version_number = text[2...4]
	offset_to_first_idf = text[4...8]
	bitstream = text_to_bitstream(text[8...-1])
	return bitstream
end

def text_to_bitstream(text)
	stream = []
	text.each_byte do |c|
		number = c.ord
		bits = []
		while number > 0 do
			bits.push((number % 2).to_s)
			number = (number - number % 2) / 2
                end
		binary = (bits.join("") + "00000000") [0...8]
		stream.push(binary)
        end
	return stream.join("")
end

def handle_vertical(a0, a0color, delta, reference_line, index)
	i = get_b1_index(reference_line, a0, index)
	if i % 2 != a0color
		i = i + 1
        end
        return i
end

def get_b1_index(reference_line, a0, index)
	for i in index...reference_line.length do
		if reference_line[i] > a0
			return i
                end
        end
	return -1
end

def decode_item(bitstream , dic)
	mode = nil
	for i in 0...14 do
		if dic.has_key?(bitstream[0...i] )
			mode = bitstream[0...i]
                end
        end
	if mode then
		return dic[mode], bitstream[mode.length..-1]
	else
		print "NO MODE FOUND!", bitstream[0...50]
                return -1
        end
end

def decode_segment(bitstream, black, white)
	whites, bitstream = decode_item(bitstream, white)
        if whites < 0 then
                return 0,0,[]
        end
	if whites > 0 and whites % 64 == 0 then
		whites_complement, bitstream = decode_item(bitstream, white)
		whites = whites + whites_complement
        end
	blacks, bitstream = decode_item(bitstream, black)
	if blacks > 0 and blacks % 64 == 0 then
		blacks_complement, bitstream = decode_item(bitstream, black)
		blacks = blacks + blacks_complement
        end
	return whites, blacks, bitstream
end
	
def get_mode(bitstream)
	mode = ""
	MODES.each do |m|
		if bitstream[0...m.length] == m then
			bitstream = bitstream[m.length..-1]
			mode = m
			break
                end
        end
	return mode, bitstream
end

def decode(bitstream, width, black, white)
	reference_line = [0, 1728]
	output = []
	new_line = [0]
	index = 0
	mode = "?"
	a0 = 0
	a0color = CODE_BLACK
        line_edge = 0
	while !bitstream.empty? do
		mode, bitstream = get_mode(bitstream)
		if mode == HORIZONTAL then
			if  a0color == CODE_BLACK then
				first, second, bitstream = decode_segment(bitstream, black, white)
			else
				first, second, bitstream = decode_segment(bitstream, white, black)
                        end
			new_line.push(first + line_edge)
			a0 =  (second + new_line[-1])
			new_line.push(a0)
			line_edge = a0
			a0color = new_line.length  % 2
		elsif VMODES.include?(mode) then
			delta = DELTAS[VMODES.index(mode)]
			index = handle_vertical(a0, a0color, delta, reference_line, index)

			if index < reference_line.length then
				new_item = reference_line[index] + delta
				if new_item > new_line[-1] then
					new_line.push(new_item)
					line_edge = new_item
					if delta > 0 then
						a0 = new_item
					else
						a0 = reference_line[index]
                                        end
					a0color = new_line.length % 2
				else
					index = index + 2
					new_item = reference_line[index]  + delta
					if new_item > new_line[-1] then
						new_line.push(new_item)
						line_edge = new_item
						if delta > 0 then
							a0 = new_item
						else
							a0 = reference_line[index]
                                                end
						a0color = new_line.length  % 2
                                        end
                                end
                        end

                elsif mode == PASS then
			original_index = index
			index = get_b1_index(reference_line, a0, index)
			b1 = reference_line[index]
			b1color = index % 2

                        if a0color ==b1color then
				if index == reference_line.length - 1 then
					index = index - 1
				else
					index = index + 1
                                end
				line_edge = reference_line[index]
				a0 = reference_line[index]
			else
				index = index + 2
				line_edge = reference_line[index]
				a0 = reference_line[index]
                        end
		else
			puts "NO MODE FOUND!"
			puts bitstream[0...35]
			return output
                end

                if a0 == PAGE_WIDTH then
			output.push(new_line)
			reference_line = output[-1]
			new_line = [0]
			a0 = 0
			line_edge = 0
			a0color = CODE_BLACK
			index = 0
                end
        end
	return output
end

def display(bitstream, canvas)
	return
end
def create_gui(bitstream)
        root = TkRoot.new() { title "Canvas, Grid, and Scrollbars" }
        vbar = TkScrollbar.new(root) { orient 'vert' }
        hbar = TkScrollbar.new(root) { orient 'hori' }
        canvas = TkCanvas.new(root) {
                width   800
                height  600
                scrollregion '0 0 3000 3000'
        }
        canvas.yscrollbar(vbar)
        canvas.xscrollbar(hbar)

        TkGrid.grid(canvas, vbar, 'sticky'=>'ns')
        TkGrid.grid(canvas, hbar, 'sticky'=>'ew')

        TkGrid.columnconfigure(root, 0, 'weight'=>1)
        TkGrid.rowconfigure(   root, 0, 'weight'=>1)
        
	for i in 0...bitstream.length do
		line = bitstream[i]
		for j in (0...line.length - 1).step(2) do
                        TkcLine.new(canvas, line[j], i, line[j+1], i, 'fill' => 'black')
		end
        end
        return root
end

FILENAME = "/home/lifman/hello_world/CCITT_3.TIF"

BLACK, WHITE = create_black_and_white_dics()
bitstream = get_bitstream(FILENAME)
pixels = decode(bitstream, PAGE_WIDTH, BLACK, WHITE)
root = create_gui(pixels)
root.mainloop()
