import { ReactNode } from 'react';
import styled from 'styled-components';

interface ButtonProps {
  children: string | ReactNode;
  margin?: string;
  width?: string;
  onClick: () => void;
}

const CustomButton = styled.span<ButtonProps>`
  min-height: 36px;
  padding: 7px 13px;
  margin: ${props => props?.margin || "0px"};
  width: ${props => props?.width || "auto"};
  color: rgba(${props => props.theme.fontColor || '255, 255, 255'}, 0.9);
  background-color: rgba(103, 61, 129, .34);
  border: 1px solid rgba(180, 123, 207, .42);
  text-align: center;
  border-radius: ${props => props.theme.borderRadius || "4px"};
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 5px;
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  cursor: pointer;
  &:hover { background-color: rgba(103, 61, 129, .52); border-color: rgba(194, 143, 218, .65); }
`;

const Button = ({ children, onClick, margin, width }: ButtonProps) => {
  return <CustomButton onClick={onClick} margin={margin} width={width}>{children}</CustomButton>;
};

export default Button;
