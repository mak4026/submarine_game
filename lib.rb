# coding: utf-8
module Ex_array
	Empty = false

	def make2d(n, obj = nil)
		a = Array.new(n)
		for i in 0...n
			a[i] = Array.new(n,obj)
		end
		a
	end

	# 5x5の配列をずらす
	# dist[0] or dist[1] == 0 が想定されてます
	def slide(array, dist)
		new_array = Array.new(5)
		if dist[1] == 0
			if dist[0] == 0
				raise ArgumentError, "distance = [0,0]"
			end
			new_array = slide(array.transpose,[dist[1],dist[0]])
			new_array = new_array.transpose
		else
			m = dist[1]
			if m > 0
				for i in 0...5-m
					new_array[i+m] = array[i]
				end
				for i in 0...m
					new_array[i] = [Empty] * 5
				end
			else
				for i in 0...5+m
					new_array[i] = array[i-m]
				end
				for i in 0...(-m)
					new_array[4-i] = [Empty] * 5
				end
			end
		end
		return new_array
	end

	def product(array1,array2)
		new_array = make2d(5)
		for i in 0...5
			for j in 0...5
				new_array[i][j] = array1[i][j] && array2[i][j]
			end
		end
		new_array
	end

	def convert(field)
		array = make2d(5,Empty)
		field.each { |f|
			array[f[0]][f[1]] = true
		}
		array
	end

	def invert(array)
		field_list = []
		for i in 0...5
			for j in 0...5
				if array[i][j]
					field_list.push([i,j])
				end
			end
		end
		field_list
	end
end
