require('test/unit')
load('lib.rb')

class T_lib < Test::Unit::TestCase
	include Ex_array

	def test_slide
		a = [[1,2,3,4,5],
			[6,7,8,9,10],
			[11,12,13,14,15],
			[16,17,18,19,20],
			[21,22,23,24,25]]
		assert_equal(slide(a,[1,0]),
			[[Empty,1,2,3,4],
			[Empty,6,7,8,9],
			[Empty,11,12,13,14],
			[Empty,16,17,18,19],
			[Empty,21,22,23,24]])

		assert_equal(slide(a,[0,2]),
			[[Empty,Empty,Empty,Empty,Empty],
			[Empty,Empty,Empty,Empty,Empty],
			[1,2,3,4,5],
			[6,7,8,9,10],
			[11,12,13,14,15]])

		assert_equal(slide(a,[-3,0]),
			[[4,5,Empty,Empty,Empty],
			[9,10,Empty,Empty,Empty],
			[14,15,Empty,Empty,Empty],
			[19,20,Empty,Empty,Empty],
			[24,25,Empty,Empty,Empty]])
		
		assert_equal(slide(a,[0,-3]),
			[[16,17,18,19,20],
			[21,22,23,24,25],
			[Empty,Empty,Empty,Empty,Empty],
			[Empty,Empty,Empty,Empty,Empty],
			[Empty,Empty,Empty,Empty,Empty]])

		assert_raise(ArgumentError){
			slide(a,[0,0])
		}
	end

	def test_product
		a = [[true,false,false,true,false],
			[false,false,false,false,false],
			[true,true,true,true,true],
			[false,false,false,false,false],
			[true,false,true,false,true]]
		b = [[false,true,true,true,false],
			[true,true,true,true,true],
			[true,true,true,true,true],
			[false,false,false,false,false],
			[true,true,false,false,false]]

		assert_equal(product(a,b),
			[[false,false,false,true,false],
			[false,false,false,false,false],
			[true,true,true,true,true],
			[false,false,false,false,false],
			[true,false,false,false,false]])
	end
	
	def test_convert
		a = [[true,false,false,true,false],
			[false,false,false,false,false],
			[true,true,true,true,true],
			[false,false,false,false,false],
			[true,false,true,false,true]]
		field = [[0,0], [0,3], [2,0], [2,1], [2,2], [2,3], [2,4],
				[4,0], [4,2], [4,4]]
		assert_equal(convert(field), a)
	end

	def test_invert
		a = [[true,false,false,true,false],
			[false,false,false,false,false],
			[true,true,true,true,true],
			[false,false,false,false,false],
			[true,false,true,false,true]]
		field = [[0,0], [0,3], [2,0], [2,1], [2,2], [2,3], [2,4],
				[4,0], [4,2], [4,4]]
		assert_equal(invert(a), field)
	end

end
