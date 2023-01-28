return {
  parse('ti', '<${1:div}>${2}</${1}>'),
  parse('tb', [[
<${1:div}>
  ${2}
</${1}>
  ]]),
  parse('im', 'import ${1} from \'${2}\''),
  parse('rc', [[
import { FC${1} } from 'react'
import { Box, Grid, Typography, styled } from '@mui/material'

export const Component: FC<Props> = props => {
  return (
    null
  )
}
  ]]),
}
