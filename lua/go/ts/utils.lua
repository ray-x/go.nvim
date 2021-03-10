local M = {}
M.intersects = function(row, col, sRow, sCol, eRow, eCol)
  -- print(row, col, sRow, sCol, eRow, eCol)
  if sRow > row or eRow < row then
    return false
  end

  if sRow == row and sCol > col then
    return false
  end

  if eRow == row and eCol < col then
    return false
  end

  return true
end

return M
