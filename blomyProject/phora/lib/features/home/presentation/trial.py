def spiral_order(matrix):
    if not matrix or not matrix[0]:
        return []

    result = []
    top, bottom = 0, len(matrix) - 1
    left, right = 0, len(matrix[0]) - 1

    while top <= bottom and left <= right:
        for col in range(left, right + 1):
            result.append(matrix[top][col])
        top += 1

        for row in range(top, bottom + 1):
            result.append(matrix[row][right])
        right -= 1

        if top <= bottom:
            for col in range(right, left - 1, -1):
                result.append(matrix[bottom][col])
            bottom -= 1

        if left <= right:
            for row in range(bottom, top - 1, -1):
                result.append(matrix[row][left])
            left += 1

    return result


def test_3x3():
    m = [[1,2,3],[4,5,6],[7,8,9]]
    assert spiral_order(m) == [1,2,3,6,9,8,7,4,5]

def test_3x4():
    m = [[1,2,3,4],[5,6,7,8],[9,10,11,12]]
    assert spiral_order(m) == [1,2,3,4,8,12,11,10,9,5,6,7]

def test_single_row():
    assert spiral_order([[1,2,3,4]]) == [1,2,3,4]

def test_single_column():
    assert spiral_order([[1],[2],[3]]) == [1,2,3]

def test_single_cell():
    assert spiral_order([[42]]) == [42]

def test_empty():
    assert spiral_order([]) == []
    assert spiral_order([[]]) == []

def test_no_duplicates():
    result = spiral_order([[1,2,3],[4,5,6],[7,8,9]])
    assert len(result) == len(set(result))

def test_all_elements_present():
    m = [[1,2,3],[4,5,6],[7,8,9]]
    assert sorted(spiral_order(m)) == list(range(1, 10))


if __name__ == "__main__":
    test_3x3()
    test_3x4()
    test_single_row()
    test_single_column()
    test_single_cell()
    test_empty()
    test_no_duplicates()
    test_all_elements_present()
    print("all tests passed")